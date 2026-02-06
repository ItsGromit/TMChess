void SelectPromotion(const string &in promotion) {
    if (gameId.Length == 0) return;
    Json::Value j = Json::Object();
    j["type"] = "select_promotion";
    j["gameId"] = gameId;
    j["promotion"] = promotion;
    SendJson(j);
}
