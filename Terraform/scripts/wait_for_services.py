import boto3
import argparse
import time
import sys

def wait_for_services(cluster, services, region):
    client = boto3.client('ecs', region_name=region)
    services_list = services.split(',')
    
    print(f"Waiting for services: {services_list} in cluster {cluster}...")

    # 1. Wait for services to exist and be ACTIVE
    while True:
        try:
            response = client.describe_services(cluster=cluster, services=services_list)
            found_services = {s['serviceName']: s for s in response['services']}
            
            all_active = True
            missing = []
            inactive = []

            for service_name in services_list:
                # The service name in describe_services response might be the full ARN or just the name
                # We check if we found a service definition that matches
                service = found_services.get(service_name)
                # Also check if the service name is part of the ARN if exact match failed
                if not service:
                     for s in response['services']:
                         if s['serviceName'] == service_name or s['serviceArn'].endswith(f"/{service_name}"):
                             service = s
                             break
                
                if not service:
                    missing.append(service_name)
                    all_active = False
                    continue
                
                if service['status'] != 'ACTIVE':
                    inactive.append(f"{service_name}({service['status']})")
                    all_active = False

            if all_active:
                print("All dependency services are ACTIVE.")
                break
            
            if missing:
                print(f"Waiting for services to be created: {missing}")
            if inactive:
                print(f"Waiting for services to be ACTIVE: {inactive}")
            
            time.sleep(10)
            
        except client.exceptions.ClusterNotFoundException:
            print(f"Cluster {cluster} not found yet. Waiting...")
            time.sleep(10)
        except Exception as e:
            print(f"Error checking services: {e}")
            time.sleep(10)

    # 2. Wait for services to be stable (runningCount == desiredCount)
    print("Waiting for services to stabilize (runningCount == desiredCount)...")
    while True:
        try:
            response = client.describe_services(cluster=cluster, services=services_list)
            unstable = []
            
            for service in response['services']:
                name = service['serviceName']
                desired = service['desiredCount']
                running = service['runningCount']
                
                if running < desired:
                    unstable.append(f"{name} ({running}/{desired})")
            
            if not unstable:
                print("All dependency services are stable.")
                break
            
            print(f"Waiting for services to stabilize: {unstable}")
            time.sleep(10)

        except Exception as e:
            print(f"Error checking service stability: {e}")
            time.sleep(10)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Wait for ECS services to be stable.')
    parser.add_argument('--cluster', required=True, help='ECS Cluster Name')
    parser.add_argument('--services', required=True, help='Comma-separated list of service names')
    parser.add_argument('--region', required=True, help='AWS Region')

    args = parser.parse_args()
    wait_for_services(args.cluster, args.services, args.region)
