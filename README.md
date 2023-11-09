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

- **Log-generator**
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

  > [!NOTE]  
  > You can change expose_port with each not binding port you want. 
  
  ```bash
  systemctl enable --now log-generator
  ```
  You can test that with this command:
  ```bash
  nc -k -lv $expose_port
  ```

- **Config Rsyslog to send logs to kafka**
- 
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
            broker=["dbaas.abriment.com:32744"]
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
