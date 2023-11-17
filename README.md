# log-management-rsyslog
Log management with netcat-rsyslog-kafka-logstash-elastic

## Scenario
### Log generation
First we generate sample json log with script in 2 way:
1. `random_city`: Generate log with bash script.
  ```json
  {"$date_time" "$random_char" "iran": {"city": "Tehran","population": "$population","men": "$(($population*$percentage/100))","women": "$(($population*(100-$percentage)/100))","hOffset": "$(($population*2))","vOffset": "100","weather": "$sun"}
  ```

2. `random_person`: Get data from API.
  ```json
  {"results":[{"gender":"male","name":{"title":"Mr","first":"سام","last":"نجاتی"},"location":{"street":{"number":5093,"name":"شهید آرش مهر"},"city":"اراک","state":"سیستان و بلوچستان","country":"Iran","postcode":85524,"coordinates":{"latitude":"14.8221","longitude":"-66.8774"},"timezone":{"offset":"-5:00","description":"Eastern Time (US & Canada), Bogota, Lima"}},"email":"sm.njty@example.com","login":{"uuid":"6a38607d-4498-492f-93ca-369819d90283","username":"smallostrich271","password":"circus","salt":"prLILh0M","md5":"dfafa1f6203c7589964d8e39d1dc4beb","sha1":"21996887ab6481a45e9694e6bc9281bf93fc214f","sha256":"c26345cd8199200d0016a03de687a7428df7d6c348a0ce5ec1260b4b3b1ead8b"},"dob":{"date":"1967-09-05T20:28:25.316Z","age":56},"registered":{"date":"2013-11-30T11:00:16.765Z","age":9},"phone":"006-85015204","cell":"0902-142-6178","id":{"name":"","value":null},"picture":{"large":"https://randomuser.me/api/portraits/men/50.jpg","medium":"https://randomuser.me/api/portraits/med/men/50.jpg","thumbnail":"https://randomuser.me/api/portraits/thumb/men/50.jpg"},"nat":"IR"}],"info":{"seed":"834d64feb14ac0ec","results":1,"page":1,"version":"1.4"}}
  ```

Then we use systemd service for that.

### Expose log on sepecific port
We use netcat to send logs to rsyslog TCP or UDP port.

### Send logs to kafka
Then write template that uses Kafka output module of Rsyslog.

### Parse logs
Use logstash to parse logs and send that to Elasticsearch.

### Log store and search
Using Elasticsearch. Then create index pattern, index template, index lifecycle policies.

## Install
- **Netcat**
  ```bash
  yum install nc
  ```
  
- **Rsyslog**
  ```bash
  cd /etc/yum.repos.d/
  wget http://rpms.adiscon.com/v8-stable-daily/rsyslog-daily.repo # for CentOS 7,8,9
  wget http://rpms.adiscon.com/v8-stable-daily/rsyslog-daily-rhel.repo # for RHEL 7,8,9
  yum install rsyslog rsyslog-kafka
  ```

  > **Note**  
  > You can run Rsyslog as a Docker Container or Kubernetes Deployment:
  > 
  > [https://itnext.io/run-rsyslog-server-in-kubernetes-bb51a7a6e227]
  > 
  > [https://itnext.io/run-rsyslog-server-in-kubernetes-bb51a7a6e227]
  > 
  > [https://github.com/puzzle/kubernetes-rsyslog-logging/tree/master]

  > **Note**
  > There is [GUI Dashboard](https://lggr.io/) for Rsyslog that you can use that.

- **Log-generator**
- 
  First we should copy [generator.sh](./generator.sh) to `/opt/log-generator/`
  Then define log-generator.service in `/etc/systemd/system/`
  ```bash
  [Unit]
  Description=Log Generator
  
  [Service]
  Environment="expose_port=9080"
  ExecStart=/opt/log-generator/generator.sh random_person

  [Install]
  WantedBy=multi-user.target
  ```

  > **Note**
  > You can change expose_port with each not binding port you want. 
  
  ```bash
  systemctl enable --now log-generator
  ```
  You can test that with this command:
  ```bash
  nc -k -lv $expose_port
  ```

- **Logstash**

  Download and install the public signing key:
  ```bash
  sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
  ```

  Add the following in your `/etc/yum.repos.d/` directory in a file with a `.repo` suffix, for example `logstash.repo`:
  ```bash
  [logstash-8.x]
  name=Elastic repository for 8.x packages
  baseurl=https://artifacts.elastic.co/packages/8.x/yum
  gpgcheck=1
  gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
  enabled=1
  autorefresh=1
  type=rpm-md
  ```

  And your repository is ready for use. You can install it with:
  ```bash
  sudo yum install logstash

  systemctl enable --now logstash
  ```

  > **Note**
  > Images are available for running Logstash as a Docker container. They are available from the Elastic Docker registry.
  > 
  > See [Running Logstash on Docker](https://www.elastic.co/guide/en/logstash/current/docker.html) for details on how to configure and run Logstash Docker containers.


- **Kafka**

- **Elasticsearch and Kibana**


## Configuration

- **Config Rsyslog to send logs to kafka**

  First we should Provide TCP syslog reception with this options in `/etc/rsyslog.conf`:
  ```
  $ModLoad imtcp
  $InputTCPServerRun 9080
  ```

  Then load module which use for sending message to kafka:
  ```
  $ModLoad omkafka
  ```

  Write template for messages that sent to kafka:
  ```
  template(name="json_lines" type="list" option.json="on") {
        constant(value="{")
        constant(value="\"timestamp\":\"")      property(name="timereported" dateFormat="rfc3339")
        constant(value="\",\"message\":\"")     property(name="msg")
        constant(value="\",\"host\":\"")        property(name="hostname")
        constant(value="\",\"severity\":\"")    property(name="syslogseverity-text")
        constant(value="\",\"facility\":\"")    property(name="syslogfacility-text")
        constant(value="\",\"syslog-tag\":\"")  property(name="syslogtag")
        constant(value="\"}")
  }
  ```

  Send just TCP syslogs on `expose_port` to kafka:
  ```
  if $inputname == "imtcp"then {
        action(type="omkafka"
            template="json_lines"
            broker=["************:****"]
            topic="logs"
            partitions.auto="on"
            confParam=[
                "socket.keepalive.enable=true"
            ]
        )
  }
  ```

  > **Note**
  > Also there are some other option that aren't use in this project but may be useful for other scenarios:
  > ```
  > # Send all logs on 192.168.20.30:514 and @@ for TCP and @ for UDP
  > *.*  @@192.168.20.30:514
  > ```
  > ```
  > # Save logs in file with this format of path
  > $template RemoteLogs,"/var/log/hosts/%HOSTNAME%/%$YEAR%/%$MONTH%/%$DAY%/syslog.log"
  > *.* ?RemoteLogs
  > ```

- **Config Logstash to parse and send logs from kafka to elastic**
  
  Create config file in `/etc/logstash/conf.d/kafka_input.conf`:
  
  ```bash
  input {
	kafka{
		bootstrap_servers => "dbaas.abriment.com:32744"
		topics => ["logs"]
		codec => json {}
	}
	}
	
	filter {
		json {
		source => "message"
		}
	}
	
	output {
	elasticsearch {
		hosts => ["https://dbaas.abriment.com:30358"]
		ssl_verification_mode => "none"
		user => "elastic"
		password => "SAra@131064"
		index => "kafka_test"
	}
	}
  ```

  You can check config with this command:/etc/logstash/logstash.yml
  ```bash
  bin/logstash -f configfile.conf --config.reload.automatic
  ```

  You can check logs in `/var/log/logstash/logstash-plain.log`

  Logstash configs like `pipeline.workers` are in `/etc/logstash/logstash.yml` that you can change them for better performance.


- **Elasticsearch configuration**
  You should have index with proper shard and replica number due to cluster and architecture. Then you should create Index Template and Index Lifecycle Policy.

  ![image](https://github.com/arezvani/log-management-rsyslog/assets/20871524/5177ec20-ef78-4c13-9658-ebb24d863030)
