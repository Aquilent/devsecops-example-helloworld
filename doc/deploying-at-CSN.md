# Deploy at CSN 

The cloud-formation scripts in this example are written using a non-CSN account.
Booz Alen CSN account have some restruictions to prevent the automated installation
from running. The CSN Policies disallow the creation of AWS VPC and AWS IAM resources
by account owners. In stead, these types of resources must be created by CSN personnel.

Furthermore, AWS resources, specifically EC instances that you create can not by default
by exposed to the public internet. They must be attached to a resources, usually an
Elastic Load Balancer (ELB) that (also) must be created by CSN personnel.

In preparation for this the cloud formation stacks are seperated in different tiers:

- [Networking](../cloud-formation/network) (or AWS VPC resources)
- [Security](../cloud-formation/security) (or AWS IAM resources)
- [Hello World](../cloud-formation/helloworld) and [Jenkins](../cloud-formation/jenkins)
  applications, mostly EC2 instances and a ECR Registry

When working in a CSN account it is not possible to run the cloud formation stacks for 
Networking nor for Security yourself. CSN has indicated that you can provide them with 
cloud-formation templates. NOte that at this time it is unclear if any of the constructs 
used are in conflict with the CSN policies.

The [main installer](../cloud-formation/main.yml) would have to be separated in one
that creates the networking and security resources, and one that creates the application
resources, such that the first can be handed to CSN. A challenge  is that this requires 
a non-CSN in order to test.

Some of the changes that likely need to be made to the scripts themself:

- Add network address translation (NAT) via NAT instance(s) or a NAT Gateway
- Add an private routing table that has an outbound rull to redirect traffic bound for any
  address to the NAT Gateway and/or a NAT instance.
- Security Groups and NACLs may need to get more specific rules added to allow access from
  specific CIDR ranges (reflecting internal Booz Allen resources) on specific protocols/ports
  (Currently, the scripts allow for accessing servers from priviledged CIDR ranges on any
  protocol/port)
- ECR is not allow (by default). Either get permission to use it, or run a
  [docker registry](https://hub.docker.com/_/registry/) docker container on a EC2 instance 
  backed by an [S3 storage driver](https://docs.docker.com/registry/storage-drivers/s3/) to
  ensurte the images are persisted on S3 and not on EBS (because of durability).

