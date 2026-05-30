```
aws --endpoint-url=http://localhost:4566 s3 cp dopka.txt s3://s3-start-bucket/

```

```
aws --endpoint-url=http://localhost:4566 s3 ls s3://s3-finish-bucket/

```

```
aws --endpoint-url=http://localhost:4566 logs describe-log-streams --log-group-name /aws/lambda/copy-s3-file

```

```
aws --endpoint-url=http://localhost:4566 logs get-log-events --log-group-name /aws/lambda/copy-s3-file --log-stream-name "logStreamName_Вставити_Сюди_значення"

```