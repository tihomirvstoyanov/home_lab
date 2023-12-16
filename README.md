# Baby Enterprise 

###### Terrafrom `main.tf` file will build AWS infrastructure that will support high availability web application, refer the diagram below:

/diagram to be added here/

#### Requirements
- Terraform & AWS CLI installed on your PC
- SSH keys pairs generated prior the execution of the script
- `variables.tfvars` file locally defined inside the `terraform init` folder

#### Steps
1. Create local SSH key-pair that will be used to connect to the Bastion host (EC2) `# ssh-keygen -t rsa -f ~/.ssh/id_rsa`

2. Create `variables.tfvars` within the same folder where you will be using `main.tf`. Add following content inside:
```
pc_ip_addr   = "<your_local_pc_ip_address>/32" #Can be obtained from https://www.whatismyip.com/
pub_key      = "<public_key_content_created_from_step_1>" # e.g. content of id_rsa.pub
rds_password = "<rds_password>" # Choose strong password that will be used to connect to the RDS database from the application EC2s
``` 
3. Add your AWS SDK keys in `~/.aws/credentials` file, if you are unfamiliar with this follow: [AWS CLI setup](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) (section 6)

4. All set up to build the AWS infrastructure, execute following commands in a sequence:
```
1. terraform init
2. terraform fmt
3. terraform validate
4. terraform plan -var-file=variables.tfvars
5. terraform apply -var-file=variables.tfvars
```

#### Connect to Bastion & Web-App EC2s
- Once build is complete it will show you the IP address of the Bastion host. Bastion will be used as a hop station that will give you access to the Web-App EC2s (as they are placed in private subnet with no public exposure). Execute following commands in sequence to connect to the Bastion host:
```
1. eval $(ssh-agent)
2. ssh-add ~/.ssh/id_rsa
3. ssh ec2-user@<bastion_host_public_ip_addr>
```
- You`ll need your private key (id_rsa) placed on the Bastion host so you can SSH from there to the web-app EC2s. That you can achieve in many ways that I wont explain in this guide.
- To connect to the web-app EC2s use: `	ssh ec2-user@<private_ip_addr_of_web_app_ec2>`