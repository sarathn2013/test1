AWS OpsWorks
===

This terraform script will create a IAM Policy, IAM Role and attach it to opsworks stack, VPC, Subnet, Internet Gateway, route table, stack, layer, application and instance.

Pre - Requisites:
---

Create SSH Key using following command 

```
ssh-keygen -f mykey
```

You will be using this keypair for launching ec2 instances

You also need to update the vars.tf.example with your aws access keys and rename the fil to vars.tf 
