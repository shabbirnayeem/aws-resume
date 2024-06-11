resource "aws_dynamodb_table" "visitorcount" {
  name           = "VisitorCount"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "id"
    type = "S"
  }

}