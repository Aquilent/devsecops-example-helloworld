#!groovy

import groovy.json.JsonSlurper

pipeline {
	agent none
    parameters {
        string(name: 'APP_NAME',
            defaultValue: 'helloworld',
            description: '')
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
		stage("Package") {
			agent { docker "maven:3.5.0-jdk-8-alpine"}
			steps {
                sh "(cd ./webapp; mvn clean package)"
             }
		}
		// stage("Publish") {
		// 	agent { docker "garland/aws-cli-docker"}
		// 	steps { publishPackages() }
		// }
		// stage("Deploy to dev") {
		// 	agent { docker "garland/aws-cli-docker"}
		// 	steps { deployPackages(env.ENVIRONMENT) }
		// }
		// stage("Proceed to test?") {
		// 	agent none
		// 	when { branch 'master' }
		// 	steps { proceedTo('test') }
		// }
		// stage("Deploy to test") {
		// 	agent { docker "garland/aws-cli-docker"}
        //     when { expression { (env.BRANCH_NAME == 'master') && (env.PROCEED_TO_TEST == 'yes' ) } }
		// 	steps { deployPackages('test') }
		// }
	}
//     post { 
//         failure { 
//             slackSend color: "warning", message: "${env.SLACK_JOB_REFERENCE} failed"
//         }
//         success { 
//             slackSend color: "good", message: "${env.SLACK_JOB_REFERENCE} succeeded"
//         }
//    }
}



// ================================================================================================
// Initialization steps
// ================================================================================================

def initialize() {
	//prepareSlack()
	// slackSend "${env.SLACK_JOB_REFERENCE} started"
    setEnvironment()
	env.APP_NAMES = "HelloWorld"
	env.TARGET_DIR = "${env.WORKSPACE}/target"
	echo "TARGET_DIR=${env.TARGET_DIR}"
    showEnvironmentVariables()
	sh "mkdir -p ${env.TARGET_DIR}"
}

// def prepareSlack() {
//     def jobName = env.JOB_NAME.replace('%2F', '/')
//     def mention = getSlackMention(getGitAuthor())
//     env.SLACK_JOB_REFERENCE = ((mention) ? "${mention} " : "") + 
//         "${jobName}: Build ${env.BUILD_NUMBER}"
// }

// def getGitAuthor() {
//     return sh(script: "git show --name-only | awk '/^Author:/ {print \$2;}' | tr '\n' ' '",
//         returnStdout: true).trim()
// }

// def getSlackMention(author) {
//     if (env.SLACK_USER_MAPPING == "") {
//         echo "Environment variable 'SLACK_USER_MAPPING' not defineds"
//         return ""
//     }
//     echo "Getting ${author} from ${env.SLACK_USER_MAPPING}"
//     def slurper = new JsonSlurper()
//     def mapping = slurper.parseText(env.SLACK_USER_MAPPING)
//     def slackUser = mapping[author]
//     echo "slackUser=${slackUser}"
//     return (slackUser) ? "@${slackUser}" : ""
// }

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

// def buildPackages() {
//     def appNames = getApplications()
//     def i = 0 
// 	for (i = 0; i < appNames.length; i++) {
// 	    def name = appNames[i]
//     	def packageFile = getLocalFilePath(name)
//     	dir("${env.WORKSPACE}/src/${name}") {
// 			sh "rm -f ${packageFile} version.txt"
// 			sh "echo 'Build:' > version.txt"
// 			sh "echo '   Date: '\$(date) >> version.txt"
// 			sh "echo '   Number: ${env.BUILD_NUMBER}' >> version.txt"
// 			zip zipFile: "${packageFile}"
//     		stash name: "${name}", include: "${packageFile}"
// 			sh "rm -f version.txt"
//     	}
// 	}
// }

// ================================================================================================
// Publish steps
// ================================================================================================

// def publishPackages() {
//    	def bucket = env.PROVISIONING_BUCKET
//     def appNames = getApplications()
//     def i = 0 
// 	for (i = 0; i < appNames.length; i++) {
// 	    def name = appNames[i]
//     	def packageFile = getLocalFilePath(name)
//     	def newKey = getFunctionArtifactKey(name, env.BUILD_NUMBER)
//     	unstash name: "${name}"
//     	aws_cli "s3api put-object --bucket ${bucket} --key ${newKey} --body ${packageFile}"
// 	}
// }

// ================================================================================================
// Deploy steps
// ================================================================================================

// def deployPackages(environment) {
//    	def bucket = env.PROVISIONING_BUCKET
//     def appNames = getApplications()
//     def i = 0 
// 	for (i = 0; i < appNames.length; i++) {
// 	    def name = appNames[i]
//     	def key = getFunctionArtifactKey(name, env.BUILD_NUMBER)
//     	def latestKey = getFunctionArtifactKey(name, environment)
//     	def functionName = getFunctionArn(name, environment)
// 		// Copy 'name' file to latest 'environment' alias
//      	aws_cli "s3api copy-object --copy-source ${bucket}/${key} --bucket ${bucket} " +
//  		 	"--key ${latestKey}"
// 		// Publish version to 'environment' function
//     	aws_cli "lambda update-function-code --publish --function-name ${functionName}" + 
//     		"  --s3-bucket ${bucket} --s3-key ${key}"
// 	}
// }


// ================================================================================================
// Utility steps
// ================================================================================================

// def getFunctionArtifactKey(name, version) {
// 	def prefix = "${env.SYSTEM_NAME}${env.SUBSYSTEM_NAME}"
// 	return getFunctionArtifactPath() + "/${prefix}-${name}-${version}.zip"
// }

// def getFunctionArtifactPath() {
// 	def prefix = "${env.SYSTEM_NAME}${env.SUBSYSTEM_NAME}"
// 	return "applications/${prefix}/${prefix}-api"
// }

// def getFunctionArn(name, environment) {
// 	def prefix = "${env.SYSTEM_NAME}${env.SUBSYSTEM_NAME}"
// 	return "arn:aws:lambda:us-east-1:${env.AWS_ACCOUNT}:function:${prefix}-${environment}-${name}"
// }

// def getLocalFilePath(name) {
// 	return "${env.TARGET_DIR}/${name}.zip"
// }

// def getApplications() {
// 	return env.APP_NAMES.split(",")
// }

// def aws_cli(command, region = null) {
// 	if (!region) {
// 		region = env.AWS_REGION
// 	}
// 	sh "aws ${command} --region ${region}"
// }

def proceedTo(environment) {
    def description = "Choose 'yes' if you want to deploy to this build to " + 
        "the ${environment} environment"
    timeout(time: 4, unit: 'HOURS') {
        env.PROCEED_TO_TEST = input message: "Do you want to deploy the changes to ${environment}?",
            parameters: [choice(name: "Deploy to ${environment}", choices: "no\nyes",
                description: description)]
    }
}

