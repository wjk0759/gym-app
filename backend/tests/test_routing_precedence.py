from app.services.coach_control.claims import claim_conflicts, match_claim


def test_claim_precedence_for_known_collisions():
    cases = {
        "把哑铃卧推换成杠铃卧推": "training.edit_day_exercise",
        "把蝴蝶机夹胸换成绳索夹胸": "training.edit_day_exercise",
        "我把哑铃换成杠铃": "profile.update_equipment",
        "我有哑铃和弹力带": "profile.update_equipment",
        "不喜欢深蹲": "training.dislike_exercise",
        "不喜欢吃鸡胸肉": "diet.dislike_food",
        "今晚吃什么": "diet.meal_detail",
        "今天午餐吃什么": "diet.meal_detail",
        "生成今晚的餐单": "diet.generate_day",
        "安排明天午餐吃什么": "diet.generate_day",
    }
    for message, expected in cases.items():
        assert match_claim(message) == expected, (message, expected)


def test_plain_food_logging_has_no_claim():
    assert match_claim("午餐吃了鸡胸肉") is None
    assert match_claim("今天体重73kg") is None
    assert match_claim("膝盖好了，腰还疼") is None


def test_conflict_helper_blocks_the_losing_capability():
    message = "把哑铃卧推换成杠铃卧推"
    assert claim_conflicts(message, "profile.update_equipment") is True
    assert claim_conflicts(message, "diet.dislike_food") is True
    assert claim_conflicts(message, "training.edit_day_exercise") is False
