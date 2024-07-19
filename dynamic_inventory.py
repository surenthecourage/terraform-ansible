#!/usr/bin/env python3

import boto3
import json
import argparse

def get_instances():
    ec2 = boto3.client('ec2')
    response = ec2.describe_instances()
    instances = []
    
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            if instance['State']['Name'] == 'running':
                instances.append(instance)
    
    return instances

def generate_inventory(instances):
    inventory = {
        'all': {
            'hosts': [],
            'vars': {}
        },
        '_meta': {
            'hostvars': {}
        }
    }

    for instance in instances:
        instance_id = instance['InstanceId']
        public_ip = instance.get('PublicIpAddress')
        private_ip = instance.get('PrivateIpAddress')

        inventory['all']['hosts'].append(instance_id)
        inventory['_meta']['hostvars'][instance_id] = {
            'ansible_host': public_ip or private_ip,
            'private_ip': private_ip,
            'public_ip': public_ip,
            'ansible_user': 'ubuntu',
            'ansible_ssh_private_key_file': "~/.ssh/id_rsa"
        }

    return inventory

def main():
    parser = argparse.ArgumentParser(description="Ansible dynamic inventory script")
    parser.add_argument('--list', action='store_true', help='List all instances')
    parser.add_argument('--host', help='Get details of a specific instance')
    args = parser.parse_args()

    instances = get_instances()
    inventory = generate_inventory(instances)

    if args.list:
        print(json.dumps(inventory, indent=2))
    elif args.host:
        hostvars = inventory['_meta']['hostvars'].get(args.host, {})
        print(json.dumps(hostvars, indent=2))
    else:
        parser.print_help()

if __name__ == '__main__':
    main()
