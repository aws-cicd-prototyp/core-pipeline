SHELL = /bin/bash

AWS_DEVOPS_PROFILE=default
AWS_PROD_PROFILE=michi.prod
AWS_REGION ?= eu-central-1

DEVOPS_ACCOUNT_ID=147376585776
WORKLOAD_ACCOUNT_ID=496106771575

help:
	@echo "Usage: "
	@echo -e "\nTo deploy all CorePipeline-Stacks:"
	@echo "   'make deploy'"
	@echo -e "\nTo destroy all CorePipeline-Stacks:"
	@echo "   'make destroy'"

deploy: _deployBaseBootstrap _deployCrossAccountRole _deployCorePipeline
destroy: _destroyCorePipeline _destroyCrossAccountRole _destroyBootstrapBase

# ---------------------------------------------
# Deploy CorePipeline-Stacks:
# ---------------------------------------------
_deployBaseBootstrap:
	@echo "Creating the baseBootstrap Stack..."
	@aws cloudformation create-stack \
		--stack-name bootstrapBase \
		--template-body file://stacks/base-bootstrap-devops.yaml \
		--parameters \
                	ParameterKey="RemoteAccountTest",ParameterValue=${WORKLOAD_ACCOUNT_ID} \
        --capabilities CAPABILITY_NAMED_IAM \
		--profile ${AWS_DEVOPS_PROFILE} \
		--region ${AWS_REGION}

	@echo "Waiting till all resources have been created... this can take some minutes"
	@aws cloudformation wait stack-create-complete \
		--stack-name bootstrapBase \
		--profile ${AWS_DEVOPS_PROFILE} \
		--region ${AWS_REGION}
	@echo "successful created!"

_deployCrossAccountRole:
	@echo "Creating the bootstrapCrossAccount Stack..."
	@aws cloudformation create-stack \
		--stack-name bootstrapCorePipelineCrossAccount \
		--template-body file://stacks/bootstrap-workload-account.yaml \
		--parameters \
        			ParameterKey="DevOpsAccount",ParameterValue=${DEVOPS_ACCOUNT_ID} \
        		  	ParameterKey="CodePipelineKmsKeyArn",ParameterValue=$(shell $(call getOutputValueOfStack,bootstrapBase,${AWS_DEVOPS_PROFILE},arn:aws:kms)) \
        		  	ParameterKey="ArtifactBucket",ParameterValue=$(shell $(call getOutputValueOfStack,bootstrapBase,${AWS_DEVOPS_PROFILE},codepipeline-artifacts-test)) \
		--profile ${AWS_PROD_PROFILE} \
		--capabilities CAPABILITY_NAMED_IAM \
		--region ${AWS_REGION}

	@echo "Waiting till all resources have been created... this can take some minutes"
	@aws cloudformation wait stack-create-complete \
		--stack-name bootstrapCorePipelineCrossAccount \
		--profile ${AWS_PROD_PROFILE} \
		--region ${AWS_REGION}
	@echo "successful created!"

_deployCorePipeline:
	@echo "Creating the bootstrapCorePipeline Stack..."
	@aws cloudformation create-stack \
		--stack-name bootstrapCorePipeline \
		--template-body file://stacks/bootstrap-devops-account.yaml \
		--parameters \
        			ParameterKey="RemoteAccountTest",ParameterValue=${WORKLOAD_ACCOUNT_ID} \
        		  	ParameterKey="BaseStack",ParameterValue="bootstrapBase" \
		--profile ${AWS_DEVOPS_PROFILE} \
		--capabilities CAPABILITY_NAMED_IAM \
		--region ${AWS_REGION}

	@echo "Waiting till all resources have been created... this can take some minutes"
	@aws cloudformation wait stack-create-complete \
		--stack-name bootstrapCorePipeline \
		--profile ${AWS_DEVOPS_PROFILE} \
		--region ${AWS_REGION}
	@echo "successful created!"

# ---------------------------------------------
# Destroy CorePipeline-Stacks:
# ---------------------------------------------
_destroyCorePipeline:
	@echo -e "\n Start deletion of bootstrapCorePipeline Stack"
	@aws cloudformation delete-stack --stack-name bootstrapCorePipeline --region ${AWS_REGION} --profile ${AWS_DEVOPS_PROFILE}
	@echo "   wait for deletion..."
	@aws cloudformation wait stack-delete-complete --stack-name bootstrapCorePipeline --region ${AWS_REGION} --profile ${AWS_DEVOPS_PROFILE}
	@echo "   Deletion successful finished!"

_destroyCrossAccountRole:
	@echo -e "\n Start deletion of bootstrapCorePipelineCrossAccount Stack"
	@aws cloudformation delete-stack --stack-name bootstrapCorePipelineCrossAccount --region ${AWS_REGION} --profile ${AWS_PROD_PROFILE}
	@echo "   wait for deletion..."
	@aws cloudformation wait stack-delete-complete --stack-name bootstrapCorePipelineCrossAccount --region ${AWS_REGION} --profile ${AWS_PROD_PROFILE}
	@echo "   Deletion successful finished!"

_destroyBootstrapBase:
	@echo -e "\n Start deletion of bootstrapBase Stack"
	@aws cloudformation delete-stack --stack-name bootstrapBase --region ${AWS_REGION} --profile ${AWS_DEVOPS_PROFILE}
	@echo "   wait for deletion..."
	@aws cloudformation wait stack-delete-complete --stack-name bootstrapBase --region ${AWS_REGION} --profile ${AWS_DEVOPS_PROFILE}
	@echo "   Deletion successful finished!"

define getOutputValueOfStack
	aws cloudformation describe-stacks --stack-name ${1} --profile ${2} --region ${AWS_REGION} | jq '.Stacks[] | .Outputs[] | select(.OutputValue | contains("${3}")) | .OutputValue'
endef
