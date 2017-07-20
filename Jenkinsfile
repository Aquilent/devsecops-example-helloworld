#!groovy

import groovy.json.JsonSlurper

pipeline {
	agent none
    parameters {
        string(name: 'REGISTRY_URL',
            defaultValue: 'https://912661153448.dkr.ecr.us-east-1.amazonaws.com/hello-world',
            description: 'URL of the docker registry used to manage hello-world images')
        string(name: 'REGISTRY_CREDENTIALS_ID',
            defaultValue: 'AWS-ECR-helloworld',
            description: 'Credentials need to connect to the docker registry')
    }
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
             }
		}
        stage("Build and Register Image") {
            agent any
            steps {
                buildAndRegisterDockerImage(params.REGISTRY_URL, params.REGISTRY_CREDENTIALS_ID) 
            }
        }
        stage("Deploy Image to Dev") {
            agent any
            steps {
                deployImage('dev', params.REGISTRY_URL, params.REGISTRY_CREDENTIALS_ID) 
            }
        }
		stage("Proceed to test?") {
			agent none
			when { branch 'master' }
			steps { proceedTo('test') }
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

def buildAndRegisterDockerImage(url, credentialsID) {
    def buildResult
	docker.withRegistry(url, credentialsID) {
        echo "Connect to registry at ${url}"
        withCredentials([[
            $class: 'UsernamePasswordMultiBinding', 
            credentialsId: credentialsID,
            usernameVariable: 'USERNAME',
            passwordVariable: 'PASSWORD']]) 
        {
            sh "docker login -u $USERNAME -p $PASSWORD ${url}"
        }
        echo "Build ${env.IMAGE_NAME}"
        buildResult = docker.build(env.IMAGE_NAME)
        echo "Register ${env.IMAGE_NAME} at ${url}"
        buildResult.push()
        echo "Disconnect from registry at ${url}"
        sh "docker logout ${url}"
    }
}

// ================================================================================================
// Deploy steps
// ================================================================================================


def deployImage(environment, url, crdentialsId) {
    def context = getContext(environment)
    def ip = findIp(environment)
    echo "Deploy ${env.IMAGE_NAME} to 'dev' environment"
    withCredentials([[
        $class: 'UsernamePasswordMultiBinding', 
        credentialsId: credentialsID,
        usernameVariable: 'USERNAME',
        passwordVariable: 'PASSWORD']]) 
    {
        sshagent (credentials: ["${env.SYSTEM_NAME}-${context}-helloworld"]) {
            sh """
                ssh -o StrictHostKeyChecking=no -tt \"ec2-user@${ip}\" \
                    sudo /opt/dso/deploy-app  \"${env.IMAGE_NAME}\" \
                        \"${url}\" \"${USERNAME}:${PASSWORD}\"
"""
        }
    }
}

def getContext(environment) {
    return isMaster() ? environment : 'dev'
}

def findIp(environment) {
    def ip = sh(returnStdout: true,
        script: """/usr/local/bin/aws ec2 describe-instances \
            --filters "Name=instance-state-name,Values=running" \
            "Name=tag:Name,Values=${env.SYSTEM_NAME}-${environment}-helloworld" \
            --query "Reservations[].Instances[].{Ip:PublicIpAddress}" \
            --output text --region ${env.AWS_REGION} | tr -d '\n'
"""
    )
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
