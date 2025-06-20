# NT548 Lab 2 - Task 2 - AWS CodePipeline Deployment

## Step 1: Configure AWS CLI

First, configure the AWS CLI to connect to your AWS account:

```bash
aws configure
```

You will be prompted to provide the following:

- **AWS Access Key ID**
- **AWS Secret Access Key**
- **Default region name**: `ap-southeast-1`
- **Default output format**: `json` (or leave blank)

---

## Step 2: Create Required Secrets

| Secret Key          | Description                                                                         |
| ------------------- | ----------------------------------------------------------------------------------- |
| `GITHUB_TOKEN`      | GitHub Personal Access Token to access private repositories                         |

---

### Creating Secrets using PowerShell + AWS CLI

Create a dictionary of secret key-value pairs:

```powershell
$secrets = @{
  "GITHUB_TOKEN" = "ghp_xxx"         # Replace with your actual GitHub token
}

foreach ($name in $secrets.Keys) {
    aws secretsmanager create-secret `
        --name $name `
        --secret-string $secrets[$name]
}
```

---

## Step 3: Deploy CodePipeline using CloudFormation

Run the following command to create the CodePipeline CloudFormation stack:

```bash
aws cloudformation create-stack \
  --stack-name nt548-lab2-codepipeline \
  --template-body file://codepipeline.yml \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM 

```

---

## Important Notes

- Make sure **all required secrets** are created in AWS Secrets Manager **before** stack deployment.
- The `stack-name` used for the CodePipeline must be **different** from the stack used to deploy infrastructure (currently named `nt548-lab2`).
- Ensure your GitHub token has the necessary permissions (`repo`, `workflow`) for pipeline access.
