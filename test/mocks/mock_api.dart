class MockAPI {
  Future<String> login(String user, String pass) async {
    if (user == "12819" && pass == "6779") {
      return "success";
    }
    return "failure";
  }
}