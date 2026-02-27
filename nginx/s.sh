#!/bin/bash
                       create_folder_if_not_exists() {
           local folder_path="$1"
            if [ ! -d "$folder_path" ]; then
      echo "Folder does not exist. Creating $folder_path..."
         mkdir -p "$folder_path"
           echo "Folder created successfully."
                        else
     echo "Folder already exists: $folder_path"
                 fi
                            }
    # Paths
                           base_folder="/etc/nginx"
          stubs_folder="$base_folder/generate/stubs"
                     port_config_stub="$stubs_folder/nginx_template_local_port.conf.stub"
                        html_config_stub="$stubs_folder/nginx_template_html_project.conf.stub"
                      php_config_stub="$stubs_folder/nginx_template_php_project.conf.stub"
                        php_projects_dir="/var/www/php"
   html_projects_dir="/var/www/html"
 # Output configuration folder
     output_folder="${base_folder}/sites-available/generated"
       create_folder_if_not_exists $output_folder
                     # Check if stub files exist
       if [[ ! -f "$port_config_stub" || ! -f "$html_config_stub" || ! -f "$php_config_stub" ]]; then
  echo "Error: One or more template stub files are missing in $stubs_folder."
                 exit 1
                        fi


        # Ask for subdomain name
          read -p "Enter subdomain name (e.g., tt, source-safe): " subdomain_input
                    subdomain="$subdomain_input.amjad.cloud"
                       config_file="$output_folder/$subdomain"


echo "New subdomain: $subdomain"


       # Ask for certificate location (default to 'amjad.cloud-0001')
 read -p "Enter certificate location (default: amjad.cloud-0001): " cert_location
            cert_location=${cert_location:-amjad.cloud-0001}

                    # Ask whether the subdomain will serve a local port or a project
                            echo -e "Will the subdomain serve:\n1. Local Port\n2. Project"
 read -p "Enter 1 or 2: " service_type


  # Validate service type
           if [[ "$service_type" != "1" && "$service_type" != "2" ]]; then
    echo "Invalid input. Please choose either '1' or '2'."
         exit 1
                        fi


        # Local Port Configuration
        if [[ "$service_type" == "1" ]]; then
 read -p "Enter the local port (e.g., 5000): " local_port

            # Validate port
                   if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [ "$local_port" -lt 1 ] || [ "$local_port" -gt 65535 ]; then                         echo "Invalid port. Please enter a number between 1 and 65535."
exit 1
                        fi


        # Generate configuration from the local port stub
              sed -e "s/{{subdomain}}/$subdomain/g" \
                            -e "s/{{cert_location}}/$cert_location/g" \
                    -e "s/{{local_port}}/$local_port/g" \
                          "$port_config_stub" > "$config_file"

                            echo "Local port configuration created: $config_file"

           # Project Configuration
           elif [[ "$service_type" == "2" ]]; then
                            echo -e "Is it:\n1. HTML Project\n2. PHP Project"
              read -p "Enter 1 or 2: " project_type


  if [[ "$project_type" == "1" ]]; then
 # HTML Project
                    read -p "Enter the root directory under $html_projects_dir/: " root_dir
                     root_directory="$html_projects_dir/$root_dir"

                       # Ask for the index file (default: index.html)
                 read -p "Enter the index file (default: index.html): " index_file
                           index_file=${index_file:-index.html}


   # Generate configuration from the HTML stub
                    sed -e "s/{{subdomain}}/$subdomain/g" \
                            -e "s/{{cert_location}}/$cert_location/g" \
                    -e "s/{{index_file}}/$index_file/g" \
                          -e "s|{{root_directory}}|$root_directory|g" \
                  "$html_config_stub" > "$config_file"

                            echo "HTML project configuration created: $config_file"

         elif [[ "$project_type" == "2" ]]; then
                            # PHP Project
                     read -p "Enter the root directory under $php_projects_dir/: " root_dir
                      project_root="$php_projects_dir/$root_dir"

                          # Generate configuration from the PHP stub
                     sed -e "s/{{subdomain}}/$subdomain/g" \
                            -e "s|{{project_root}}|$project_root|g" \
                      -e "s/{{cert_location}}/$cert_location/g" \
                    "$php_config_stub" > "$config_file"


echo "PHP project configuration created: $config_file"

          else
     echo "Invalid input. Please choose either '1' or '2'."
         exit 1
                        fi
                            fi





                  read -p "Press 1 to activate the generated conf file or any other key to skip: " activate

        if [[ "$activate" == "1" ]]; then
     echo "Activating the configuration file..."

                         # Create a symbolic link to enable the configuration
           ln -s "$config_file" /etc/nginx/sites-enabled/

                      # Reload Nginx
                    if nginx -t; then
                     systemctl reload nginx
            echo "Nginx configuration for $subdomain has been activated and applied successfully."
  else
     echo "Nginx configuration test failed. Please check the configuration file."
            fi
                            else
     echo "Skipped activation of the configuration file. You can activate it manually later."
fi