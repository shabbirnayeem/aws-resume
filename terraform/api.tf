resource "aws_api_gateway_rest_api" "VisitorCounterAPI" {
  name = "VisitorCounterAPI"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "visitor_count_resource" {
  rest_api_id = aws_api_gateway_rest_api.VisitorCounterAPI.id
  parent_id   = aws_api_gateway_rest_api.VisitorCounterAPI.root_resource_id
  path_part   = "count"
}

resource "aws_api_gateway_method" "visitor_count_method" {
  rest_api_id   = aws_api_gateway_rest_api.VisitorCounterAPI.id
  resource_id   = aws_api_gateway_resource.visitor_count_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "visitor_count_integration" {
  content_handling        = "CONVERT_TO_TEXT"
  rest_api_id             = aws_api_gateway_rest_api.VisitorCounterAPI.id
  resource_id             = aws_api_gateway_resource.visitor_count_resource.id
  http_method             = aws_api_gateway_method.visitor_count_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.VisitorCounter.invoke_arn
}

resource "aws_api_gateway_deployment" "visitor_count_deployment" {
  rest_api_id = aws_api_gateway_rest_api.VisitorCounterAPI.id

  depends_on = [
    aws_api_gateway_integration.visitor_count_integration
  ]
}

resource "aws_api_gateway_stage" "prd" {
  deployment_id = aws_api_gateway_deployment.visitor_count_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.VisitorCounterAPI.id
  stage_name    = "prd"
}