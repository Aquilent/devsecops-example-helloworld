#!groovy

import groovy.json.JsonSlurper

pipeline {
	agent none
    options {
        timeout(time: 1, unit: 'DAYS')
        disableConcurrentBuilds()
    }
	stages {
		stage("Init") {
			agent any
			steps { initialize() }
		}
		stage("Build App") {
			agent { docker "maven:3.5.0-jdk-8-alpine"}
			steps {
                sh "(cd ./webapp; mvn clean install)"
                archiveArtifacts 'webapp/target/spring-boot-web-jsp-1.0.war'
        		step([$class: 'JUnitResultArchiver',
                    testResults: '**/target/surefire-reports/TEST-*.xml']
                )
             }
		}
        stage("Build and Register Image") {
            agent any
            steps {
                buildAndRegisterDockerImage() 
            }
        }
        stage("Deploy Image to Dev") {
            agent any
            steps {
                deployImage(env.ENVIRONMENT) 
            }
        }
		stage("Proceed to test?") {
			agent none
            // Do not deploy non-master branches to test
            // These branches must be merged via a PR to the master branch first
			when { branch 'master' } 
			steps { proceedTo('test') }
		}
        stage("Deploy Image to Test") {
            agent any
			when { branch 'master' } 
            steps {
                deployImage('test') 
            }
        }
	}
}


// ================================================================================================
// Initialization steps
// ================================================================================================

def initialize() {
    env.SYSTEM_NAME = "DSO"
    env.IMAGE_NAME = "hello-world:${env.BUILD_ID}"
    env.AWS_REGION = "us-east-1"
    env.REGISTRY_URL = "https://912661153448.dkr.ecr.us-east-1.amazonaws.com"
    env.MAX_ENVIRONMENTNAME_LENGTH = 32
    setEnvironment()
    showEnvironmentVariables()
}

def setEnvironment() {
    def branchName = env.BRANCH_NAME.toLowerCase()
    def environment = 'dev'
    echo "branchName = ${branchName}"
    if (branchName == "") {
        showEnvironmentVariables()
        throw "BRANCH_NAME is not an environment variable or is empty"
    } else if (branchName != "master") {
		//echo "split"
        if (branchName.contains("/")) {
            // ignore branch type
            branchName = branchName.split("/")[1]
        }
        //echo "remove '-' characters'"
        branchName = branchName.replace("-", "")
        //echo "remove JIRA project name"
        if (env.JIRA_PROJECT_NAME) {
            branchName = branchName.replace(env.JIRA_PROJECT_NAME, "")
        }
        // echo "limit length"
        branchName = branchName.take(env.MAX_ENVIRONMENTNAME_LENGTH as Integer)
        environment += branchName
    }
    echo "Using environment: ${environment}"
    env.ENVIRONMENT = environment
}

def showEnvironmentVariables() {
    sh 'env | sort > env.txt'
    sh 'cat env.txt'
}

// ================================================================================================
// Build steps
// ================================================================================================

def buildAndRegisterDockerImage() {
    def url = env.REGISTRY_URL
    def buildResult
    docker.withRegistry(url) {
        echo "Connect to registry at ${url}"
	    dockerRegistryLogin(url)
        echo "Build ${env.IMAGE_NAME}"
        buildResult = docker.build(env.IMAGE_NAME)
        echo "Register ${env.IMAGE_NAME} at ${url}"
        buildResult.push()
        echo "Disconnect from registry at ${url}"
        sh "docker logout ${url}"
    }
}

def dockerRegistryLogin() {
    def url = env.REGISTRY_URL
    def login_command = ""
    withDockerContainer("garland/aws-cli-docker") {
        login_command = sh(returnStdout: true,
            script: "aws ecr get-login --region ${AWS_REGION} | sed -e 's|-e none||g'"
        )
    }
    sh "${login_command}"
}

// ================================================================================================
// Deploy steps
// ================================================================================================


def deployImage(environment, url) {
    def context = getContext(environment)
    def ip = findIp(environment)
    echo "Deploy ${env.IMAGE_NAME} to '${environment}' environment (in context: ${context})"
    sshagent (credentials: ["${env.SYSTEM_NAME}-${context}-helloworld"]) {
        sh """ssh -o StrictHostKeyChecking=no -tt \"ec2-user@${ip}\" \
            sudo /opt/dso/deploy-app  \"${env.IMAGE_NAME}\" \"${url}\"
"""
    }
    env.ECR_TOKEN = ""
}

def getContext(environment) {
    return (env.BRANCH_NAME == 'master') ? environment : 'dev'
}

def findIp(environment) {
    def ip = ""
    withDockerContainer("garland/aws-cli-docker") {
       ip = sh(returnStdout: true,
            script: """aws ec2 describe-instances \
                --filters "Name=instance-state-name,Values=running" \
                "Name=tag:Name,Values=${env.SYSTEM_NAME}-${environment}-helloworld" \
                --query "Reservations[].Instances[].{Ip:PrivateIpAddress}" \
                --output text --region ${env.AWS_REGION} | tr -d '\n'
"""
        )
    }
    echo "ip=[${ip}]"
    return ip
}


// ================================================================================================
// Utility steps
// ================================================================================================

def proceedTo(environment) {
    def description = "Choose 'yes' if you want to deploy to this build to " + 
        "the ${environment} environment"
    timeout(time: 4, unit: 'HOURS') {
        env.PROCEED_TO_TEST = input message: "Do you want to deploy the changes to ${environment}?",
            parameters: [choice(name: "Deploy to ${environment}", choices: "no\nyes",
                description: description)]
    }
}
