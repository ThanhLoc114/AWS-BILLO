class AppConfig {
  final String apiBaseUrl;
  final String awsRegion;
  final String cognitoClientId;

  const AppConfig({
    required this.apiBaseUrl,
    required this.awsRegion,
    required this.cognitoClientId,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL'),
    awsRegion: String.fromEnvironment(
      'AWS_REGION',
      defaultValue: 'ap-southeast-1',
    ),
    cognitoClientId: String.fromEnvironment('COGNITO_CLIENT_ID'),
  );

  bool get isAwsConfigured =>
      apiBaseUrl.isNotEmpty && cognitoClientId.isNotEmpty;

  Uri apiUri(String path) {
    if (apiBaseUrl.isEmpty) {
      throw const FormatException('API_BASE_URL is not configured');
    }
    final base = Uri.parse(apiBaseUrl);
    final relative = Uri.parse(path);
    return base.replace(
      path:
          '${base.path.replaceFirst(RegExp(r'/$'), '')}/'
          '${relative.path.replaceFirst(RegExp(r'^/'), '')}',
      queryParameters: relative.queryParameters.isEmpty
          ? null
          : relative.queryParameters,
    );
  }

  Uri get cognitoEndpoint =>
      Uri.parse('https://cognito-idp.$awsRegion.amazonaws.com/');
}
