# DynamoDB Table for User Data
resource "aws_dynamodb_table" "user_data" {
  name           = "${var.project_name}-user-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  
  attribute {
    name = "user_id"
    type = "S"
  }
  
  tags = {
    Name = "${var.project_name}-user-data"
  }
}
