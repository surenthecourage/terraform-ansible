#!/usr/bin/python3

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
            'hosts': {},
            'vars': {},
            'children': {}
        }
    }

    env_groups = {}

    for instance in instances:
        instance_id = instance['InstanceId']
        public_ip = instance.get('PublicIpAddress')
        private_ip = instance.get('PrivateIpAddress')

        name_tag = get_instance_tag(instance, 'Name') or instance_id
        env_tag = get_instance_tag(instance, 'Env') or 'unknown'

        # Add the host to the inventory
        inventory['all']['hosts'][name_tag] = {
            'ansible_host': public_ip or private_ip,
            'ansible_user': 'ubuntu',
            'ansible_ssh_private_key_file': "/home/surendra/.ssh/id_rsa",
            'private_ip': private_ip,
            'public_ip': public_ip
        }

        # Add the host to its environment group
        if env_tag not in env_groups:
            env_groups[env_tag] = {'hosts': {}}
        env_groups[env_tag]['hosts'][name_tag] = {}

    # Update the 'children' section of 'all'
    inventory['all']['children'].update(env_groups)

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
        hostvars = inventory['all']['hosts'].get(args.host, {})
        print(yaml.dump(hostvars, default_flow_style=False))
    elif args.output_file:
        # Only write to a file if --output-file is explicitly provided
        write_to_file(inventory, args.output_file)
    else:
        parser.print_help()

if __name__ == '__main__':
    main()