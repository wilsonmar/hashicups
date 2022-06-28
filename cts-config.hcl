# cts-config.hcl
# from https://learn.hashicorp.com/tutorials/consul/consul-terraform-sync-intro?in=consul/network-infrastructure-automation
# https://github.com/hashicorp/consul-terraform-sync-enterprise/

log_level   = "INFO"
working_dir = "sync-tasks"
port        = 8558

syslog {}

buffer_period {
  enabled = true
  min     = "5s"
  max     = "20s"
}

consul {
  address = "localhost:8500"
}

driver "terraform" {
  # version = "0.14.0"
  # path = ""
  log         = false
  persist_log = false

  backend "consul" {
    gzip = true
  }
}

task {
 name        = "learn-cts-example"
 description = "Example task with two services"
 module      = "findkim/print/cts"
 version     = "0.1.0"
 condition "services" {
  names = ["web", "api"]
 }
}

