#!/usr/bin/env bash

director_newconfig()
{
  cat <<EOF
{
  "director_configuration": {
    "ntp_servers_string": "ntp.ubuntu.com",
    "resurrector_enabled": false,
    "director_hostname": null,
    "max_threads": null,
    "custom_ssh_banner": null,
    "metrics_server_enabled": true,
    "system_metrics_runtime_enabled": true,
    "opentsdb_ip": null,
    "director_worker_count": 5,
    "post_deploy_enabled": false,
    "bosh_recreate_on_next_deploy": false,
    "bosh_director_recreate_on_next_deploy": false,
    "bosh_recreate_persistent_disks_on_next_deploy": false,
    "retry_bosh_deploys": false,
    "keep_unreachable_vms": false,
    "identification_tags": {},
    "skip_director_drain": false,
    "job_configuration_on_tmpfs": false,
    "nats_max_payload_mb": null,
    "database_type": "internal",
    "blobstore_type": "local",
    "local_blobstore_options": {
      "enable_signed_urls": true
    },
    "hm_pager_duty_options": {
      "enabled": false
    },
    "hm_emailer_options": {
      "enabled": false
    },
    "encryption": {
      "keys": [],
      "providers": []
    }
  },
  "dns_configuration": {
    "excluded_recursors": [],
    "recursor_selection": null,
    "recursor_timeout": null,
    "handlers": []
  },
  "security_configuration": {
    "trusted_certificates": null,
    "generate_vm_passwords": true,
    "opsmanager_root_ca_trusted_certs": false
  },
  "syslog_configuration": {
    "enabled": false
  },
  "iaas_configuration": {
    "name": "default",
    "additional_cloud_properties": {},
    "subscription_id": "$SUBSCRIPTION_ID",
    "tenant_id": "$TENANT_ID",
    "client_id": "$APPLICATION_ID",
    "client_secret": "$SP_PASSWORD",
    "resource_group_name": "$RESOURCE_GROUP",
    "bosh_storage_account_name": "$STORAGE_NAME",
    "cloud_storage_type": "managed_disks",
    "storage_account_type": "Premium_LRS",
    "default_security_group": null,
    "deployed_cloud_storage_type": null,
    "deployments_storage_account_name": null,
    "ssh_public_key": "$(cat ~/.ssh/azurekeys/opsman.pub)",
    "ssh_private_key": "$(cat ~/.ssh/azurekeys/opsman | tr -d '\n')",
    "environment": "AzureCloud",
    "availability_mode": "availability_zones"
  }
}
EOF
}

function configure_bosh_director(){
  echo "Configuring bosh director..."
  curl -k -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $OPSMAN_TOKEN" -d "$(director_newconfig)" "https://$OPSMAN_URL/api/v0/staged/director/properties"
}


networks_config()
{
  cat <<EOF
{
    "icmp_checks_enabled": false,
    "networks": [
      {
        "guid": null,
        "name": "infrastructure",
        "subnets": [
          {
            "guid": null,
            "iaas_identifier": "tas-virtual-network/tas-infrastructure",
            "cidr": "10.0.4.0/26",
            "dns": "168.63.129.16",
            "gateway": "10.0.4.1",
            "reserved_ip_ranges": "10.0.4.1-10.0.4.9"
          }
        ]
      },
      {
        "guid": null,
        "name": "tas",
        "subnets": [
          {
            "guid": null,
            "iaas_identifier": "tas-virtual-network/tas-runtime",
            "cidr": "10.0.12.0/22",
            "dns": "168.63.129.16",
            "gateway": "10.0.12.1",
            "reserved_ip_ranges": "10.0.12.1-10.0.12.9"
          }
        ]
      },
      {
        "guid": null,
        "name": "services",
        "subnets": [
          {
            "guid": null,
            "iaas_identifier": "tas-virtual-network/tas-services",
            "cidr": "10.0.8.0/22",
            "dns": "168.63.129.16",
            "gateway": "10.0.8.1",
            "reserved_ip_ranges": "10.0.8.1-10.0.8.9"
          }
        ]
      }
    ]
  }
EOF
}

function configure_bosh_networks(){
  curl -k -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $OPSMAN_TOKEN" -d "$(networks_config)" "https://$OPSMAN_URL/api/v0/staged/director/networks"
}

az_singleton()
{
  cat <<EOF
{
  "network_and_az": {
    "network": {
      "name": "infrastructure"
    },
    "singleton_availability_zone": {
      "name": "zone-1"
    }
  }
}
EOF
}

function configure_bosh_azs(){
  curl -k -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $OPSMAN_TOKEN" -d "$(az_singleton)" "https://$OPSMAN_URL/api/v0/staged/director/network_and_az"
}

