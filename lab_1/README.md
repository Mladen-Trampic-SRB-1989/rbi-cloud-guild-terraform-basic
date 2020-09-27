# Image Slide
![Reality](resources/lab_1.PNG)

# Commands
Step 1 initialize, to download provider
```bash
docker run --rm -it -v ${PWD}/.creds:/terraform/.creds -v ${PWD}/lab_1:/terraform -w=/terraform --user "$(id -u):$(id -g)" hashicorp/terraform:0.12.28 init
```

Step 2 terraforming
To create:
```bash
docker run --rm -it -v ${PWD}/.creds:/terraform/.creds -v ${PWD}/lab_1:/terraform -w=/terraform --user "$(id -u):$(id -g)" hashicorp/terraform:0.12.28 apply -var-file /terraform/root_module.tfvars.json 
```

To Destroy ( cleanup ):
```bash
docker run --rm -it -v ${PWD}/.creds:/terraform/.creds -v ${PWD}/lab_1:/terraform -w=/terraform --user "$(id -u):$(id -g)" hashicorp/terraform:0.12.28 destroy -var-file /terraform/root_module.tfvars.json
```

# Resource
[draw.io lab_1_final](resources/lab_1_final.drawio)
