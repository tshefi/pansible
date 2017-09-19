# pansible

A bash script which runs on undercloud and boots an instance with ssh/ping access.
Script first creates an ansible inventory file from UC's nova list.
Then uses inventory file to run preflight.yml ansible.

The preflight.yml will do a few things on the OC:
1. Create a private network/subnet.
2. A router connecting public and internal networks.
3. Downloads a Cirros image from web, uploads it to Glance.
4. Creates a Nova tiny flavor.
5. Boots an instance, while assigng both internal+public IPs.
6. Create a security group which enables ssh/ping into instance.


You must have a "public" network created, in the future one will be created via script if it's missing.