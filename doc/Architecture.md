# Architecture

This DevSecOps example uses the following architecture:

![Architecture](./images/devsecops-example-architecture.png)


- Provisioning S3 Bucket - Hold cloud formation template, stack policy and any files 
  needed to complete the provisioning using [cfn-init]()

- VPC - Virtual networking resources consisting of
    * Individual subnets (environments, Jenkins)
    * Each individual subnet has its own NACL, so it could be modified later
    * Each individual subnet has its own SecurityGroup, so it could be modified later
      These groups must be assigned to the instances in the respective subnets
    * There is one overall Security Group that defines sources ([CIDR]() blocks) of 
      priviledged access.
      These groups must be assigned to instances in the various subnets that need
      priviledged acess (specifically ssh)

- IAM - Policies defining access rules for the various resources (S3 bucket, ECR Registry,
  CloudWatch Logs). The main purpose is to defined priviledges for EC2 instances via 
  Roles/Instance Profiles. The policies are defined as limiting as possible, to allow 
  EC2 Instance to do
  [only what they need, but nothing more](https://en.wikipedia.org/wiki/Principle_of_least_privilege):
    * Provisioning Policy (S3 Access) - Access the S3 bucket for provisoining purposes
    * Logging Policy (CloudWatch Logs access) - Access to CloudWatch Logs to allow pushing of 
      log files
    * Image Push/Pull Policies (ECR Registry access) - Access to an ECR Registry to push or pull
      the hellow world application docker image
    * Individual server type roles - Roles per type and environment to combine priiledges as
      appropriate.

- CloudWatch Logs

- ECR Registry

- EC2 Instances 
    * Every instance runs Docker
    * Jenkins runs [Jenkins](https://hub.docker.com/_/jenkins/) docker image, started from a service
    * Jenkins runs [SonarQube](https://hub.docker.com/_/sonarqube/) docker image, started form aservice
    * WebServer instance run:
        - Initially, before the pipeline has run successfully at least one
          [Kitematic NGINX Hello World[(https://hub.docker.com/r/kitematic/hello-world-nginx/)
        - Subsequently, when pipeline has run [SpringBoot app image](../Dockerfile)

- [Jenkins pipeline](../Jenkinsfile)
  The Jenkins pipeline uses the fact that it runs inside the same environment
  using the assigned IAM Role to. This may not work in other setups where Jenkins is 
  hosted outside the environment.
  The pipeline does the following to 'exploit' this situation:
    * Connect to the ECR registry 
    * Discover internal server IP addresses in order to connect using SSH,
      including to connect to SonarQube from the Pipeline 
      (Connecting to localhost:9000 does not work as SonarQube runs inside a Docker container,
      thus localhost is routed to that container, rather than the docker host)
    * EC2 instances are discovered (rather than configured).
      This is more flexible, as it does not require updates to the pipeline, if the
      AWS resources are replaced
    * SSH connections to environment servers are made use Credentials IDs.
      The credentials IDs are discovered based on the name and the targe environment.




[cfn-init]: http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-init.html
[CIDR]: https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing