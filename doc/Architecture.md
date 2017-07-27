# Architecture

This DevSecOps example uses the following architecture:

![Architecture](./images/devsecops-example-architecture.png)


- Provisioning Bucket
- VPC
    * Individual subnets (environments, Jenkins)
    * Each Subnet NACL
    * Each Subnet SecurityGroup
    * Overall Priviledged access Security group
- IAM
    * Provisioning Policy (S3 Access)
    * Logging Policy (CloudWatch Logs access)
    * Image Push/Pull Policies (ECR Registry access)
    * Individual server type roles
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

