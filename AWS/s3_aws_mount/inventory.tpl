all:
  hosts:
%{ for instance in instances ~}
    ${instance.name}:
      ansible_host: ${instance.public_ip}
      ansible_user: admin
      ansible_ssh_private_key_file: /path/to/private/key.pem
%{ endfor ~}
