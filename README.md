# pansible

A bash script which runs on undercloud, creates an ansible inventory file from nova list output.
Then runs ansible.yml playbook with ^ created inventory.

The preflight.yml will:
1. create private network/subnet.
1.5 Add in the future logic to test/create public is doesn't exist yet.
2. A router
3. Download Cirros, upload to Glance
4. Create Nova flavor
5. Boot an instance, assign internal+public IP
6. Create security group which enables ssh/ping into instance.


Open to any new requests features ideas :)

