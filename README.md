# 🤖 ElizaOS Confidential Agent iApp

[![iExec TDX](https://img.shields.io/badge/iExec-TDX-00b4cc)](https://protocol.docs.iex.ec/for-developers/confidential-computing/create-your-first-tdx-app)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Execute ElizaOS AI agents with full confidentiality in iExec TDX Trusted Execution Environments (TEEs).

🧵 Use case: In this demo, the agent impersonates a custom character and posts tweets on the user’s X (Twitter) account based on the character’s personality and configuration.

## 🧠 Overview

This iExec Application (iApp) runs ElizaOS AI agents securely inside Intel TDX enclaves, providing:

- ✅ Model integrity verification using model ID (e.g., SHA-256)
- 🛡️ Full isolation of the AI stack (Eliza Agent + model)
- 🔐 Support for protected character datasets and user credentials


> [!IMPORTANT]
> To test and run this agent, you must have a twitter account identified as an automated account, otherwise your account may be suspended.


## 🧪 Local Testing with Docker

You can run and test the iApp locally in a Docker container before deploying it on iExec.

### 1. Retrieve Model Name and Model ID

To run an agent, you need:

- **Model name** (e.g., `qwen2.5:0.5b`)
- **Model ID** (e.g., `a8b0c5157701`)

➡️ Visit [https://ollama.com/search](https://ollama.com/search)
Select a model, and you will find:

- The **model name** at the top
- The **model ID** (short hash or full SHA256) in the model details/download section

> [!IMPORTANT]
> **Make sure the model is supported by ElizaOS.** Stick with small/medium-sized models like 0.5b for local runs.

### 2. Prepare the Character File

The agent expects a **character definition file** as input in the `iexec_in` folder. This file must follow the ElizaOS character format.

An example is provided in:

```bash
iexec_in/character
```

Modify it to fit your custom personality, prompt, and configuration.

> [!IMPORTANT]
> Lines 3 and 4 in the sample must not be modified, otherwise the agent will not function.
```bash
    "clients": ["twitter"],
    "modelProvider": "ollama",
```

### 3. Build the Docker Image

Build the Docker image locally:

```bash
docker build -t eliza .
```

### 4. Initialize configuration

You can edit and adjust the `.env.template` to suit your needs, **but do not touch lines 5 to 24**. For testing purposes, we recommend that you leave the file as is. Values with a `_TO_REPLACE` suffix will be replaced at runtime with automatically injected secrets. 

Moreover, this file will be used in the docker build and automatically renamed to .env, so there's no need to do this (you can see line 29 of the `Dockerfile`).

### 5. Run the iApp Locally

Run the app using Docker:

```bash
docker run --rm --name eliza \
  -v ./iexec_in:/iexec_in \
  -v ./iexec_out:/iexec_out \
  -e IEXEC_DATASET_FILENAME=character \
  -e IEXEC_IN=/iexec_in \
  -e IEXEC_OUT=/iexec_out \
  -e IEXEC_REQUESTER_SECRET_1="twitter-username" \
  -e IEXEC_REQUESTER_SECRET_2="twitter-password" \
  -e IEXEC_REQUESTER_SECRET_3="twitter-email@example.com" \
  eliza:latest "<model_name> <model_id>"
```

➡️ Result: The agent will generate and post content on your X (Twitter) profile according to the personality and behavior defined in your custom character file.

If everything's ok and you want to continue testing, then tag the image with your docker account and push it to the hub :
```bash
docker tag eliza:latest <docker-hub-user>/eliza:1.0.0
docker push <docker-hub-user>/eliza:1.0.0
```

## 🚀 Run on iExec TDX Production

### ⚙️ Install SDK

**TDX is currently an experimental environment. The associated SDK/CLI is not yet released and there are a few steps to install it.**

First move to another folder, the one of your choice, we'll clone a repo and install it.

``` bash
# clone this project locally https://github.com/aimen-djari/iexec-sdk/tree/feature/tdx
git clone --single-branch --branch feature/tdx git@github.com:aimen-djari/iexec-sdk.git

# install modules
npm install iexec

# build iExec
npm run build

# install
npm install -g .

# check version
iexec --version
#8.13.0-tdx
```

### 🛠️ Initialize wallet and project
Now,  you can create a dedicated project/folder to manage the deployment but you can also stay in the application folder, which is not a problem, and the generated files are excluded in the .gitignore file. In the rest of this readme, we'll assume that we're staying in the application/agent folder.

Create a new Wallet file
``` bash
iexec wallet create
```

Initialize your iExec project
``` bash
iexec init --skip-wallet
```
Check that the generated chain.json file is as follows:

``` json
{
  "default": "bellecour",
  "chains": {
    "bellecour": {
      "sms": { "tdx": "https://sms.labs.iex.ec" }
    }
  }
}
```

TEE applications need a few more keys in the iexec.json file; run this to add them automatically:
``` bash
iexec app init --tee-framework tdx
```

Your iexec.json should now look like this example:

``` json
{
  ...
  "app": {
    "owner": "<your-wallet-address>", // starts with 0x
    "name": "tee-scone-hello-world", // application name
    "type": "DOCKER",
    "multiaddr": "<docker-hub-user>/eliza:1.0.0", // app image
    "checksum": "<checksum>", // starts with 0x, update it with your own image digest
    "mrenclave": {
      "framework": "TDX", // TEE framework (keep default value)
    }
  },
  ...
}
```

* Normally, the `owner` is automatically filled in (via your wallet).
* Change the `multiaddr` field to match the docker image you've pushed onto the hub
* `checksum` needs to be changed

The `checksum` of your app is the sha256 digest of the docker image prefixed with `0x` , you can use the following command to get it.

``` bash
docker pull <docker-hub-user>/eliza:1.0.0 | grep "Digest: sha256:" | sed 's/.*sha256:/0x/'
```

### 📦 Deploy the application

Deploy the app with the standard command:
``` bash
iexec app deploy
```

### 🔐 Push secrets to the SMS

``` bash
iexec requester push-secret twitter-username --secret-value <your-twitter-username>
iexec requester push-secret twitter-email --secret-value <your-twitter-email>
iexec requester push-secret twitter-password --secret-value <your-twitter-password>
```

### 🤖 Deploy the character as a dataset

#### Encrypt the dataset

Init the dataset configuration.
``` bash
iexec dataset init --encrypted
```
This command will create the datasets/encrypted, datasets/original and .secrets/datasets folders. A new dataset section will be added to the iexec.json file as well.

``` bash
.
├── datasets
│   ├── encrypted
│   └── original
└── .secrets
    └── datasets
```

Put your character file into `datasets/original` folder.
For example if you have directly updated the sample file in `iexec_in` :
``` bash
cp iexec_in/character datasets/original
```
Now run the following command to encrypt the file:
``` bash
iexec dataset encrypt
```
> [!NOTE]
> `iexec dataset encrypt` will output a checksum, keep this value for a later use.

``` bash
datasets
├── encrypted
│   └── character.enc
└── original
    └── character
```

As you can see, the command generated the file `datasets/encrypted/character.enc`. That file is the encrypted version of your dataset, you should push it somewhere accessible because the worker will download it during the execution process. You will enter this file's URI in the `iexec.json` file (`multiaddr` attribute) when you will deploy your dataset. Make sure that the URI is a DIRECT download link (not a link to a web page for example).

> [!NOTE]
> You can use Github for example to publish the file but you should add /raw/ to the URI like this:`https://github.com/<username>/<repo>/raw/master/character.enc`

The file `.secrets/datasets/character.key` is the encryption key, make sure to back it up securely. The file `.secrets/datasets/dataset.key` is just an "alias" in the sense that it is the key of the last encrypted dataset.

``` bash
.secrets
└── datasets
    ├── dataset.key
    └── character.key
```

#### Deploy the dataset
Fill in the fields of the `iexec.json` file. Choose a `name` for your dataset, put the encrypted file's URI in `multiaddr` (the URI you got after publishing the file) and fill the `checksum` field. The `checksum` of the dataset consists of a 0x prefix followed by the `sha256sum` of the dataset. This checksum is printed when running the `iexec dataset encrypt` command. If you missed it, you can retrieve the `sha256sum` of the dataset by running sha256sum `datasets/encrypted/character.enc`.

``` bash
$ cat iexec.json
{
  "description": "My iExec ressource description...",

  ...

  "dataset": {
    "owner": "0x-your-wallet-address",
    "name": "Encrypted character dataset",
    "multiaddr": "/ipfs/QmW2WQi7j6c7UgJTarActp7tDNikE4B2qXtFCfLPdsgaTQ",
    "checksum": "<0x-sha256sum-of-the-dataset>" // starts with 0x
  }
}
```

To deploy your dataset run:

``` bash
iexec dataset deploy
```
You will get a hexadecimal address for your deployed dataset. Use that address to push the encryption key to the `SMS` so it is available for authorized applications.

For simplicity, we will use the dataset with a TEE-debug app on a debug workerpool. The debug workerpool is connected to a debug Secret Management Service so we will send the dataset encryption key to this SMS (this is fine for debugging but do not use to store production secrets).


#### Push the dataset secret to the SMS
``` bash
iexec dataset push-secret
```

### ⚡Run the application

Once you have successfully tested the iApp locally and verified that tweets are being posted, you can deploy the iApp to iExec TDX production. Follow the [iExec documentation](https://protocol.docs.iex.ec/) for detailed steps.

When you're ready to run on iExec TDX (application deployed, dataset deployed, and requester secrets pushed):

```bash
iexec app run \
  --args "<model_name> <model_id>" \
  --tag tee,tdx \
  --dataset <DATASET_ADDRESS> \
  --secret 1=twitter-username \
  --secret 2=twitter-email \
  --secret 3=twitter-password \
  --workerpool tdx-labs.pools.iexec.eth \
  --skip-preflight-check \
  --watch
```

> [!IMPORTANT]
> `twitter-username`, `twitter-email` and `twitter-password` are the labels defined when you pushed the secrets, you must not indicate here the real values of your identifiers.
