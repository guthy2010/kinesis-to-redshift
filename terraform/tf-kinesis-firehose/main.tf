provider "aws" {
  alias = "kinesis"
  region = "eu-central-1"
  profile = "kinesis"
}
provider "aws" {
  alias = "redshift"
  region = "eu-central-1"
  profile = "redshift"
}
####################
# Cross account role
####################
resource "aws_iam_role" "firehose_role" {
  provider = aws.kinesis
  name = "firehose_test_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#########################
# s3 cross account Bucket
#########################
resource "aws_s3_bucket" "jimdo-redshift-bucket" {
  provider = aws.redshift
  bucket = "jimdo-redshift-bucket"

  tags = {
    Name        = "jimdo-redshift-bucket"
    Environment = "prod"
  }

  policy = <<POLICY
{

    "Version": "2012-10-17",
    "Id": "PolicyID",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "${aws_iam_role.firehose_role.arn}"
            },
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            "Resource": [
                "arn:aws:s3:::jimdo-redshift-bucket",
                "arn:aws:s3:::jimdo-redshift-bucket/*"
            ]
        }
    ]
}
POLICY
}
####################
# Kinesis policy
####################
resource "aws_iam_policy" "firehose_role_s3_policy" {
  provider = aws.kinesis
  name       = "firehose_role_s3_policy"
  description = "Policy to access data stream"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucketMultipartUploads",
                "s3:AbortMultipartUpload",
                "s3:PutObjectVersionAcl",
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:PutObjectAcl"
            ],
            "Resource": [
                "arn:aws:s3:::jimdo-redshift-bucket",
                "arn:aws:s3:::jimdo-redshift-bucket/*"
            ]
        }
    ]
}
EOF
}
#########################
# Attach to firehose role
#########################
resource "aws_iam_role_policy_attachment" "kinesis_policy_attach" {
  provider = aws.kinesis
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_role_s3_policy.arn
}

#########################
# Firehose Stream
#########################
resource "aws_kinesis_firehose_delivery_stream" "jimdo_test_stream" {
  provider = aws.kinesis
  name        = "kinesis-jimdo-test-stream"
  destination = "s3"

  s3_configuration {
    buffer_interval = 100
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = "arn:aws:s3:::jimdo-redshift-bucket"
  }
}

