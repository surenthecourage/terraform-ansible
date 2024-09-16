#!/usr/bin/env python3

import boto3
import yaml  # For YAML output
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

def get_instance_tag(instance, key):
    """Retrieve the value of a specific tag (e.g., 'Name', 'Env') for the EC2 instance."""
    value = None
    if 'Tags' in instance:
        for tag in instance['Tags']:
            if tag['Key'] == key:
                value = tag['Value']
    return value

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

    # Dictionary to hold hosts grouped by Env tag (e.g., dev, prod)
    env_groups = {}

    for instance in instances:
        instance_id = instance['InstanceId']
        public_ip = instance.get('PublicIpAddress')
        private_ip = instance.get('PrivateIpAddress')

        # Get the Name tag or fall back to instance_id if not available
        name_tag = get_instance_tag(instance, 'Name') or instance_id

        # Get the Env tag to group instances
        env_tag = get_instance_tag(instance, 'Env') or 'unknown'

        # Add the instance to the inventory under 'all' and under the specific env group
        inventory['all']['hosts'].append(name_tag)
        
        # Grouping instances by Env tag
        if env_tag not in env_groups:
            env_groups[env_tag] = {'hosts': []}
        env_groups[env_tag]['hosts'].append(name_tag)

        # Add hostvars for this instance
        inventory['_meta']['hostvars'][name_tag] = {
            'ansible_host': public_ip or private_ip,
            'private_ip': private_ip,
            'public_ip': public_ip,
            'ansible_user': 'ubuntu',
            'ansible_ssh_private_key_file': "~/.ssh/id_rsa"
        }

    # Add the env groups to the inventory
    inventory.update(env_groups)

    return inventory

def write_to_file(inventory, file_path):
    """Write the inventory to a YAML file."""
    with open(file_path, 'w') as file:
        yaml.dump(inventory, file, default_flow_style=False)

def main():
    parser = argparse.ArgumentParser(description="Ansible dynamic inventory script")
    parser.add_argument('--list', action='store_true', help='List all instances')
    parser.add_argument('--host', help='Get details of a specific instance')
    parser.add_argument('--output-file', help='Write inventory to a YAML file')
    args = parser.parse_args()

    instances = get_instances()
    inventory = generate_inventory(instances)

    if args.list:
        # Only print the inventory in YAML format (do not write to a file)
        print(yaml.dump(inventory, default_flow_style=False))
    elif args.host:
        hostvars = inventory['_meta']['hostvars'].get(args.host, {})
        print(yaml.dump(hostvars, default_flow_style=False))
    elif args.output_file:
        # Only write to a file if --output-file is explicitly provided
        write_to_file(inventory, args.output_file)
    else:
        parser.print_help()

if __name__ == '__main__':
    main()