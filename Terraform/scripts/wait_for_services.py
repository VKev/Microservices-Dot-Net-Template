import boto3
import argparse
import time
import sys
import datetime

def wait_for_services(cluster, services, region, timeout_minutes=20):
    client = boto3.client('ecs', region_name=region)
    services_list = services.split(',')
    
    print(f"Waiting for services: {services_list} in cluster {cluster}...")
    print(f"Timeout set to {timeout_minutes} minutes.")
    
    start_time = datetime.datetime.now()
    timeout_delta = datetime.timedelta(minutes=timeout_minutes)

    # 1. Wait for services to exist and be ACTIVE
    while True:
        if datetime.datetime.now() - start_time > timeout_delta:
            print(f"TIMEOUT: Exceeded {timeout_minutes} minutes waiting for services to be ACTIVE.")
            sys.exit(1)

        try:
            response = client.describe_services(cluster=cluster, services=services_list)
            
            # Log failures if any
            if response.get('failures'):
                print(f"DEBUG: Failures reported: {response['failures']}")

            found_services = {s['serviceName']: s for s in response['services']}
            print(f"DEBUG: Found services: {list(found_services.keys())}")
            
            all_active = True
            missing = []
            inactive = []

            for service_name in services_list:
                service = found_services.get(service_name)
                if not service:
                     # Try to find by ARN suffix if name match failed
                     for s in response['services']:
                         if s['serviceName'] == service_name or s['serviceArn'].endswith(f"/{service_name}"):
                             service = s
                             break
                
                if not service:
                    missing.append(service_name)
                    all_active = False
                    continue
                
                print(f"DEBUG: Service {service_name} status: {service['status']}")
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
        if datetime.datetime.now() - start_time > timeout_delta:
            print(f"TIMEOUT: Exceeded {timeout_minutes} minutes waiting for services to stabilize.")
            sys.exit(1)

        try:
            response = client.describe_services(cluster=cluster, services=services_list)
            unstable = []
            
            for service in response['services']:
                name = service['serviceName']
                desired = service['desiredCount']
                running = service['runningCount']
                pending = service['pendingCount']
                
                if running < desired:
                    unstable.append(f"{name} (Running: {running}/{desired}, Pending: {pending})")
            
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
    parser.add_argument('--timeout', type=int, default=20, help='Timeout in minutes')

    args = parser.parse_args()
    wait_for_services(args.cluster, args.services, args.region, args.timeout)
