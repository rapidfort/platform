# RapidFort Platform Installation Guide
1. Launch Debian 12 EC2 instance, 8 cores, 16GB RAM, 512GB disk, internet access
2. Bootstrap VM
    ```
    sudo su -
    apt update
    apt install git -y
    git clone https://github.com/rapidfort/platform
    cd platform
    ./install_dependencies.sh
3. Create secret.yaml (contents provided by RapidFort)
4. Create user.yaml (contents provided by RapidFort)
5. Create image.yaml (contents provided by RapidFort)
6. Deploy Platform
    ```
    ./deploy_platform.sh
    watch kubectl get pods
    ```
7. Create Admin User
    ```
    ./bootstrap_admin_user.sh "<Company Name>"
    ```