### Create and mount a secret in an Amazon EKS pod
In this tutorial, you create an example secret in Secrets Manager, and then you mount the secret in an Amazon EKS pod and deploy it.

Before you begin, install the ASCP: Install the ASCP. 

```
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install -n kube-system csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver
```
```
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
```

## To create and mount a secret

# Set the AWS Region and the name of your cluster as shell variables so you can use them in bash commands. For , enter the AWS Region where your Amazon EKS cluster runs. For , enter the name of your cluster.
```
REGION=<REGION>
CLUSTERNAME=<CLUSTERNAME>
```
  
# Create a test secret. For more information, see Create a secret.

```
aws --region "$REGION" secretsmanager  create-secret --name MySecret --secret-string '{"username":"arun-user", "password":"P@$$Adm!n"}'
```
or
```
aws secretsmanager create-secret  --name MyTestSecret  --secret-string file://mycreds.json
```

# Create a resource policy for the pod that limits its access to the secret you created in the previous step. For , use the ARN of the secret. Save the policy ARN in a shell variable.

```
POLICY_ARN=$(aws --region "$REGION" --query Policy.Arn --output text iam create-policy --policy-name test-deployment-policy --policy-document '{
    "Version": "2012-10-17",
    "Statement": [ {
        "Effect": "Allow",
        "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
        "Resource": ["<SECRETARN>"]
    } ]
}')
```
# Create an IAM OIDC provider for the cluster if you don't already have one.
```
eksctl utils associate-iam-oidc-provider --region="$REGION" --cluster="$CLUSTERNAME" --approve # Only run this once
```

# Create the service account the pod uses and associate the resource policy you created in step 3 with that service account.

```
eksctl create iamserviceaccount --name test-deployment-sa --region="$REGION" --cluster "$CLUSTERNAME" --attach-policy-arn "$POLICY_ARN" --approve --override-existing-serviceaccounts
```

# Create the SecretProviderClass to specify which secret to mount in the pod and set the directory to mount the secret you created above in the manifest.

```
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: aws-secrets
spec:
  provider: aws
  parameters:
    objects: |
        - objectName: "MyTestSecret"
          objectType: "secretsmanager"
```

Deploy your pod. The following command uses ExampleDeployment.yaml in the ASCP GitHub repo examples directory to mount the secret in /mnt/secrets-store in the pod.

```
kind: Service
apiVersion: v1
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      serviceAccountName: deployment-sa-arun
      volumes:
      - name: secrets-store-arun
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "aws-secrets"
      containers:
      - name: nginx-deployment
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: secrets-store-arun
          mountPath: "/mnt/secrets-store"
          readOnly: true
```

To verify the secret has been mounted properly, use the following command and confirm that your secret value appears.
```
kubectl exec -it <pod name> /bin/bash

  cat /mnt/secrets-store/MyTestSecret
  ```
