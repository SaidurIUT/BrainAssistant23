# Start:
### 1. Prerequisites

* Before starting, ensure you have the following installed:

* Docker and Docker Compose.

* Git (which you clearly have).

* A .env file: The compose files reference env_file: .env. You likely need to create this from a template. Check for a .env.example file in your directory.

```
cp .env.example .env
```

### 2. Running in Development (Recommended)
   The standard docker-compose.yaml is set up for a development workflow with hot-reloading (via Vite).

  Step A: Build the images
This will take a few minutes as it installs Ruby gems and Node packages.

```
  docker-compose build
```

  Step B: Prepare the Database
Since this is a Rails app, you need to create and seed the database.

```
docker-compose run --rm rails bundle exec rake db:create
docker-compose run --rm rails bundle exec rake db:schema:load
docker-compose run --rm rails bundle exec rake db:seed

```

  Step C: Start the services
```
docker-compose up
```

### 3. Now explore the BrainAssistant23

Access the App: Open http://localhost:3000 in your browser.

Mailhog: Access http://localhost:8025 to see outgoing emails in development.


Initial seed credentials

Email:
```
john@acme.inc
```
Password:
```
Password1!
```

If you want to enable account signup, go to http://localhost:3000/super_admin/app_config?config=general then make Enable Account Signup = True

Nevigate to http://localhost:8025 for emails in test mode

# Storage:
The config/storage.yml file defines several storage services:

* Local Disk: For test (in tmp/storage) and local (in storage) environments.
* Amazon S3: Configured via AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, and S3_BUCKET_NAME environment variables.
* Google Cloud Storage (GCS): Configured via GCS_PROJECT, GCS_CREDENTIALS, and GCS_BUCKET environment variables.
* Microsoft Azure Storage: Configured via AZURE_STORAGE_ACCOUNT_NAME, AZURE_STORAGE_ACCESS_KEY, and AZURE_STORAGE_CONTAINER environment variables.
* S3-compatible services: Allows integration with other S3-compatible storage solutions using relevant environment variables.

In a production environment, the specific storage service used (e.g., AWS S3, GCS, or Azure) is determined by the config.active_storage.service setting in the application's environment
configuration (typically config/environments/production.rb), which would reference one of the services defined in config/storage.yml. If no specific cloud service is configured, it might
default to local disk storage depending on the setup.

