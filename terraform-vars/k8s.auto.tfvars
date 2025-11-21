# Kubernetes deployment settings (used when use_eks = true)
kubernete = {
  namespace         = "microservices"
  redis_password    = "0Kg04Rs05!"
  rabbitmq_username = "rabbitmq"
  rabbitmq_password = "0Kg04Rq08!"
  jwt_secret        = "YourSuperSecretKeyThatIsAtLeast32CharactersLong!@#$%^&*()"
  guest_db = {
    host     = "pg-1-database25811.g.aivencloud.com"
    port     = 16026
    name     = "guestdb"
    username = "avnadmin"
    password = "AVNS_iGi4kJJObNRnGdM6BTb"
    provider = "postgres"
  }
  user_db = {
    host     = "pg-2-database25812.g.aivencloud.com"
    port     = 19217
    name     = "userdb"
    username = "avnadmin"
    password = "AVNS_vsIotPLRrxJUhcJlM0m"
    provider = "postgres"
    ssl_mode = "Require"
  }
}
