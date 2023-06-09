#!/bin/bash

# Update and upgrade the system
sudo apt-get update
sudo apt-get upgrade
sudo apt-get --purge autoremove
sudo snap refresh
# ------------------------------------------------------------

# Install dependencies
sudo apt-get install -y curl gpg default-jdk default-jre
# ------------------------------------------------------------

# Configure the Elastic Stack repository
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch \
  | sudo gpg --dearmor -o /usr/share/keyrings/elastic.gpg
echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" \
  | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
sudo apt-get update
# ------------------------------------------------------------

# Install Elasticsearch
sudo apt-get install elasticsearch
# ------------------------------------------------------------

# Configure Elasticsearch
sudo sed -i -r 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b'/"localhost"/ /etc/elasticsearch/elasticsearch.yml
# ------------------------------------------------------------

# Start and enable Elasticsearch
sudo systemctl start elasticsearch
sudo systemctl enable elasticsearch
# ------------------------------------------------------------

# Test Elasticsearch
curl -X GET http://localhost:9200
# ------------------------------------------------------------

# Install Kibana
sudo apt-get install kibana
# ------------------------------------------------------------

# Start and enable Kibana
sudo systemctl enable kibana
sudo systemctl start kibana
# ------------------------------------------------------------

# Install Logstash
sudo apt-get install logstash
# ------------------------------------------------------------

# Configure Logstash
sudo cat /etc/logstash/conf.d/02-beats-input.conf <<EOF
input {
  beats {
    port => 5044
  }
}
EOF

sudo cat /etc/logstash/conf.d/30-elasticsearch-output.conf <<EOF
output {
  if [@metadata][pipeline] {
	elasticsearch {
  	hosts => ["localhost:9200"]
  	manage_template => false
  	index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
  	pipeline => "%{[@metadata][pipeline]}"
	}
  } else {
	elasticsearch {
  	hosts => ["localhost:9200"]
  	manage_template => false
  	index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
	}
  }
}
EOF
sudo -u logstash /usr/share/logstash/bin/logstash --path.settings /etc/logstash -t
# ------------------------------------------------------------

# Start and enable Logstash
sudo systemctl start logstash
sudo systemctl enable logstash
# ------------------------------------------------------------

# Install Filebeat
sudo apt-get install filebeat
# ------------------------------------------------------------

# Configure Filebeat
sudo sed -i 's/output.elasticsearch:/#output.elasticsearch:' /etc/filebeat/filebeat.yml
sudo sed -i 's/hosts: ["localhost:9200"]/#hosts: ["localhost:9200"]' /etc/filebeat/filebeat.yml
sudo sed -i 's/#output.logstash:/output.logstash:' /etc/filebeat/filebeat.yml
sudo sed -i 's/#hosts: ["localhost:5044"]/hosts: ["localhost:5044"]' /etc/filebeat/filebeat.yml
sudo filebeat modules enable system
sudo filebeat setup --pipelines --modules system
sudo filebeat setup --index-management -E output.logstash.enabled=false -E 'output.elasticsearch.hosts=["localhost:9200"]'
sudo filebeat setup -E output.logstash.enabled=false -E output.elasticsearch.hosts=['localhost:9200'] -E setup.kibana.host=localhost:5601
# ------------------------------------------------------------

# Start and enable Filebeat
sudo systemctl start filebeat
sudo systemctl enable filebeat
# ------------------------------------------------------------

# Test Filebeat
curl -XGET 'http://localhost:9200/filebeat-*/_search?pretty'
# ------------------------------------------------------------

# Install Metricbeat
sudo apt-get install metricbeat
# ------------------------------------------------------------

# Configure Metricbeat
sudo metricbeat setup --template -E 'output.elasticsearch.hosts=["localhost:9200"]'
sudo metricbeat setup -e -E output.elasticsearch.hosts=['localhost:9200'] -E setup.kibana.host=localhost:5601
# ------------------------------------------------------------

# Start and enable Metricbeat
sudo systemctl start metricbeat
sudo systemctl enable metricbeat
# ------------------------------------------------------------

# Test Metricbeat
curl -XGET 'http://localhost:9200/metricbeat-*/_search?pretty'
# ------------------------------------------------------------

# Install Grafana
wget https://dl.grafana.com/oss/release/grafana_9.5.2_amd64.deb
sudo dpkg -i grafana_9.5.2_amd64.deb
# ------------------------------------------------------------

# Start and enable Grafana
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable grafana-server
sudo /bin/systemctl start grafana-server
sudo systemctl status grafana-server
# ------------------------------------------------------------
