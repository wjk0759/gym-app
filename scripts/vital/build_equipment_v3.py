#!/usr/bin/env python3
"""Build the 70-item equipment catalog from the watermark-free image set.

The folder is the source of truth. Old catalog names are only used to resolve
stable slugs / exercise groups for the 64 machines that already existed.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
IMAGE_SOURCE = Path(r"E:\Projects\无水印光板健身器械图")
OLD_CATALOG = ROOT / "data" / "vital" / "equipment_catalog_v2.json"
OUT_CATALOG = ROOT / "data" / "vital" / "equipment_catalog_v3.json"
OUT_GUIDES = ROOT / "data" / "vital" / "equipment_guides_v3.json"
OUT_IMAGES = ROOT / "data" / "vital" / "equipment_images_v3"
OUT_IOS_CATALOG = ROOT / "ios" / "FitAI" / "Resources" / "equipment_catalog.json"
OUT_IOS_GUIDES = ROOT / "ios" / "FitAI" / "Resources" / "equipment_guides.json"
OUT_MANIFEST = ROOT / "data" / "vital" / "equipment_image_manifest_v3.json"

MANUAL_OLD = {
    "卧推架": "bench_press",
    "上斜卧推架": "incline_bench",
    "深蹲架": "squat_rack",
    "史密斯架": "smith_machine",
    "龙门架": "cable_crossover",
    "绳索划船机": "cable_row",
    "鹦鹉螺-背部下拉机": "pullover",
    "山羊挺身-背伸展机": "back_extension",
    "臀腿挺身机-GHD": "glute_ham",
    "倒蹬机": "leg_press_45",
    "腹前屈训练机": "ab_crunch",
    "分体式腹前屈机": "ab_crunch_iso",
    "屈腿伸腿训练器": "leg_extension_curl_combo",
    "双杠臂屈伸架": "pullup_dip_station",
    "助力双杠臂屈伸机": "assisted_dip",
    "助力引体向上机": "assisted_pullup",
    "反向超伸机": "reverse_hyper",
    "腹肌滑轨机": "ab_coaster",
    "躯干旋转机": "torso_rotation",
}

NEW_TYPES = {
    "分动式腿屈伸机": ("leg_extension_iso", "leg_extension"),
    "分动式腿弯举机": ("leg_curl_lying_iso", "leg_curl"),
    "单腿弯举机": ("leg_curl_single", "leg_curl"),
    "臀桥机": ("glute_bridge", "hip_thrust"),
    "硬拉机": ("deadlift_machine", "barbell"),
    "腹肌训练凳": ("ab_bench", "ab"),
}

EXTRA_EXERCISE_SLUGS = {
    "deadlift_machine": [
        "vital-stiff-legged-deadlift-machine",
        "vital-conventional-deadlift",
        "vital-hex-bar-deadlift",
        "vital-barbell-romanian-deadlift",
        "vital-deadlift-barbell",
    ],
    "v_squat": [
        "vital-landmine-v-squat",
        "vital-squat-machine",
        "vital-back-squat",
    ],
    "belt_squat": [
        "vital-squat-machine",
        "vital-back-squat",
        "vital-squat-with-high-knee",
    ],
    "pendulum_squat": [
        "vital-squat-machine",
        "vital-back-squat",
        "vital-hack-squat-machine",
    ],
    "inner_outer_thigh": [
        "vital-lean-forward-hip-abduction",
        "vital-inner-thigh-push-out-kneeling-hip-abduction",
        "vital-seated-abductor-hip-lift",
    ],
    "cable_row": [
        "vital-seated-cable-row",
        "vital-wide-grip-seated-cable-row",
        "vital-standing-cable-row",
    ],
    "squat_rack": [
        "vital-barbell-front-squat",
        "vital-barbell-elevated-back-squat",
        "vital-barbell-bulgarian-split-squat",
        "vital-barbell-bench-press-flat",
        "vital-barbell-incline-bench-press",
        "vital-barbell-romanian-deadlift",
        "vital-conventional-deadlift",
        "vital-zercher-squat",
        "vital-jefferson-squat",
    ],
    "ab_crunch": [
        "vital-crunch",
        "vital-decline-bench-crunch",
        "vital-cable-crunch",
        "vital-half-way-crunch",
        "vital-reverse-crunch",
    ],
    "ab_crunch_iso": [
        "vital-crunch",
        "vital-single-arm-side-cable-crunch",
        "vital-cross-body-knee-crunch",
        "vital-half-way-crunch",
    ],
    "ab_bench": [
        "vital-incline-sit-up",
        "vital-sit-ups",
        "vital-incline-sit-up-rotation",
        "vital-sit-ups-twist-sit-ups",
        "vital-decline-bench-crunch",
        "vital-crunch",
    ],
    "ab_coaster": [
        "vital-reverse-crunch",
        "vital-crunch",
        "vital-half-reverse-crunch",
        "vital-seated-knee-to-chest-crunch",
    ],
    "torso_rotation": [
        "vital-cable-wood-chop",
        "vital-viking-press-trunk-rotation",
        "vital-exercise-oblique-rotation-exercise-ball-kettlebell",
        "vital-incline-sit-up-rotation",
    ],
    "reverse_hyper": [
        "vital-reverse-hyperextension",
        "vital-smith-machine-reverse-hyper",
        "vital-45-degree-hyperextension-machine",
        "vital-hyperextensions-back-extensions",
    ],
    "leg_extension_curl_combo": [
        "vital-leg-extension",
        "vital-leg-extension-machine",
        "vital-lying-leg-curl-machine",
        "vital-seated-leg-curl-machine",
        "vital-lying-leg-curl",
        "vital-seated-leg-curl",
    ],
    "glute_ham": [
        "vital-nordic-curl",
        "vital-45-degree-hyperextension-machine",
        "vital-prone-back-extension",
        "vital-reverse-hyperextension",
        "vital-hyperextensions-back-extensions",
    ],
}


def E(name, body, secondary, targets, template, setup, *, cues=None):
    return {
        "name": name,
        "body_part": body,
        "secondary": secondary,
        "targets": targets,
        "template": template,
        "setup": setup,
        "cues": cues or {},
    }


SEED = [
    # 胸
    E("坐姿推胸机", "胸", ["肩", "臂"], ["胸大肌", "三角肌前束", "肱三头肌"], "horizontal_push",
      "调整座椅，使握把与胸线平齐；背贴靠垫，肩胛后缩下沉。"),
    E("分动式推胸机", "胸", ["肩", "臂"], ["胸大肌", "三角肌前束", "肱三头肌"], "horizontal_push",
      "两侧握把独立，先调好座位高度，双手同时推起，注意左右发力均衡。"),
    E("平板卧推机", "胸", ["肩", "臂"], ["胸大肌", "三角肌前束", "肱三头肌"], "horizontal_push",
      "躺平，握把在胸线位置，肩胛后缩，双脚踩实。"),
    E("上斜推胸机", "胸", ["肩", "臂"], ["胸大肌上束", "三角肌前束", "肱三头肌"], "incline_push",
      "座椅调至握把在上胸位置，背部贴垫，肩胛稳定。"),
    E("下斜推胸机", "胸", ["肩", "臂"], ["胸大肌下束", "肱三头肌", "三角肌前束"], "decline_push",
      "座椅调至握把在下胸位置，肩胛稳定，双脚踩实。"),
    E("蝴蝶机", "胸", ["肩"], ["胸大肌", "三角肌前束"], "fly",
      "调整座椅使握把与肩同高或略低，肘部微屈，背部贴垫。"),
    E("卧推架", "胸", ["肩", "臂"], ["胸大肌", "三角肌前束", "肱三头肌"], "free_weight",
      "调整卧推凳和挂钩高度，肩胛后缩，双脚踩实。"),
    E("上斜卧推架", "胸", ["肩", "臂"], ["胸大肌上束", "三角肌前束", "肱三头肌"], "free_weight",
      "上斜角度约 30–45°，肩胛后缩，杠铃下放到上胸。"),
    # 背
    E("高位下拉机", "背", ["臂"], ["背阔肌", "大圆肌", "肱二头肌", "斜方肌中下束"], "vertical_pull",
      "调整腿垫固定大腿，握距略宽于肩，先沉肩。"),
    E("分动式高位下拉机", "背", ["臂"], ["背阔肌", "大圆肌", "肱二头肌"], "vertical_pull",
      "两侧独立握把，先调好座位，保持左右对称。"),
    E("鹦鹉螺-背部下拉机", "背", ["臂"], ["背阔肌", "大圆肌", "肱三头肌长头"], "pullover",
      "调整座椅使肩关节与转轴对齐，手臂微屈。"),
    E("坐姿划船机", "背", ["臂"], ["背阔肌", "菱形肌", "斜方肌中束", "肱二头肌"], "horizontal_pull",
      "胸部贴垫，双脚踩实，握把拉向腹部。"),
    E("低位划船机", "背", ["臂"], ["背阔肌", "菱形肌", "肱二头肌"], "horizontal_pull",
      "调整座椅和胸垫，握把在腹部高度。"),
    E("高位划船机", "背", ["肩", "臂"], ["背阔肌", "三角肌后束", "菱形肌"], "horizontal_pull",
      "胸垫贴紧，握把在上胸/肩前高度，肘部向后。"),
    E("杠杆划船机", "背", ["臂"], ["背阔肌", "菱形肌", "斜方肌中束"], "horizontal_pull",
      "胸部贴垫，脚掌踩实，握把拉向腹部。"),
    E("T 杠划船机", "背", ["臂"], ["背阔肌", "菱形肌", "斜方肌中束", "肱二头肌"], "horizontal_pull",
      "站姿屈髋，背部中立，杠铃贴近身体。"),
    E("绳索划船机", "背", ["臂"], ["背阔肌", "菱形肌", "肱二头肌"], "cable_row",
      "坐稳，双脚踩实，滑轮与腹部同高。"),
    E("助力引体向上机", "背", ["臂"], ["背阔肌", "大圆肌", "肱二头肌"], "vertical_pull",
      "选择助力重量，膝跪/脚踏稳，先沉肩。"),
    E("山羊挺身-背伸展机", "背", ["臀", "腿"], ["竖脊肌", "臀大肌", "腘绳肌"], "back_extension",
      "髋部位于垫边缘，脚踝固定，脊柱中立。"),
    E("耸肩机", "背", ["肩"], ["斜方肌上束", "肩胛提肌"], "shrug",
      "肩部置于垫下，双臂伸直，肩膀垂直上提。"),
    # 肩
    E("坐姿推肩机", "肩", ["臂"], ["三角肌前束", "三角肌中束", "肱三头肌"], "vertical_push",
      "调整座椅使握把与肩同高，背部贴垫。"),
    E("分动式推肩机", "肩", ["臂"], ["三角肌前束", "三角肌中束", "肱三头肌"], "vertical_push",
      "两侧独立握把，座位调至握把与肩同高。"),
    E("侧平举机", "肩", [], ["三角肌中束"], "lateral_raise",
      "调整座椅使肘部与转轴对齐，手臂微屈。"),
    E("直立划船机", "肩", ["背", "臂"], ["三角肌中束", "斜方肌", "肱二头肌"], "upright_row",
      "握距略宽于肩，杠铃贴近身体。"),
    E("颈部训练机", "肩", ["颈"], ["胸锁乳突肌", "斜方肌", "颈部伸肌"], "neck",
      "调整头垫，颈部中立，从小幅度开始。"),
    # 臂
    E("二头肌弯举机", "臂", [], ["肱二头肌", "肱肌", "肱桡肌"], "curl",
      "上臂贴垫，肘部与转轴对齐。"),
    E("牧师凳弯举机", "臂", [], ["肱二头肌", "肱肌"], "preacher_curl",
      "上臂完全贴垫，腋窝靠近垫顶。"),
    E("三头肌下压机", "臂", [], ["肱三头肌"], "triceps_pushdown",
      "肘部固定在体侧，握把在胸腹之间。"),
    E("三头肌伸展机", "臂", [], ["肱三头肌"], "triceps_extension",
      "调整座椅使肘部与转轴对齐，上臂贴垫。"),
    E("前臂训练机", "臂", [], ["前臂屈肌", "前臂伸肌"], "forearm",
      "前臂贴垫，手腕悬空，重量轻起步。"),
    E("助力双杠臂屈伸机", "臂", ["胸"], ["肱三头肌", "胸大肌下束", "三角肌前束"], "dip",
      "选择助力重量，肩胛下沉，身体略前倾。"),
    E("双杠臂屈伸架", "臂", ["胸"], ["肱三头肌", "胸大肌下束", "三角肌前束"], "dip",
      "双手撑杠，肩胛下沉，核心收紧。"),
    # 腿
    E("腿屈伸机", "腿", [], ["股四头肌"], "leg_extension",
      "调整座椅使膝关节与转轴对齐，脚踝垫在脚背上方。"),
    E("分动式腿屈伸机", "腿", [], ["股四头肌"], "leg_extension",
      "两侧独立，先调好膝轴和踝垫，左右分别发力。"),
    E("坐姿腿弯举机", "腿", [], ["腘绳肌", "腓肠肌"], "leg_curl",
      "调整靠背使膝关节与转轴对齐，大腿压垫锁紧。"),
    E("俯卧腿弯举机", "腿", [], ["腘绳肌", "腓肠肌"], "leg_curl",
      "俯卧，膝盖对准转轴，踝垫在脚跟上方。"),
    E("分动式腿弯举机", "腿", [], ["腘绳肌", "腓肠肌"], "leg_curl",
      "俯卧/坐姿按机型，左右腿独立，髋部贴垫。"),
    E("单腿弯举机", "腿", [], ["腘绳肌", "腓肠肌"], "leg_curl",
      "单腿训练，工作腿膝轴对齐，非工作腿稳定支撑。"),
    E("站姿腿弯举机", "腿", [], ["腘绳肌"], "leg_curl",
      "站立扶稳，工作腿膝轴对齐，脚踝垫贴紧。"),
    E("屈腿伸腿训练器", "腿", [], ["股四头肌", "腘绳肌"], "leg_extension",
      "先调好伸腿和弯举两种模式的转轴与垫位。"),
    E("倒蹬机", "腿", ["臀"], ["股四头肌", "臀大肌", "腘绳肌", "内收肌"], "leg_press",
      "背部贴垫，双脚与髋同宽，膝盖对准脚尖。"),
    E("哈克深蹲机", "腿", ["臀"], ["股四头肌", "臀大肌", "腘绳肌"], "squat_machine",
      "肩垫贴稳，双脚与肩同宽，膝盖对准脚尖。"),
    E("V 型深蹲机", "腿", ["臀"], ["股四头肌", "臀大肌"], "squat_machine",
      "站入 V 型踏板，脚掌踩实，核心收紧。"),
    E("腰带深蹲机", "腿", ["臀"], ["股四头肌", "臀大肌", "腘绳肌"], "squat_machine",
      "系好腰带，脚掌踩实，屈髋屈膝下蹲。"),
    E("钟摆深蹲机", "腿", ["臀"], ["股四头肌", "臀大肌"], "squat_machine",
      "肩/背贴垫，双脚踩实，沿钟摆轨迹下蹲。"),
    E("深蹲架", "腿", ["臀", "核心"], ["股四头肌", "臀大肌", "腘绳肌", "核心"], "free_weight",
      "调整挂钩和护杠高度，杠铃置于上背/前架。"),
    E("坐姿提踵机", "腿", [], ["比目鱼肌", "腓肠肌"], "calf",
      "膝盖压垫固定，前脚掌踩踏板。"),
    E("站姿提踵机", "腿", [], ["腓肠肌", "比目鱼肌"], "calf",
      "肩垫贴稳，前脚掌踩踏板，脚跟悬空。"),
    E("胫骨前肌训练机", "腿", [], ["胫骨前肌"], "tibialis",
      "脚背勾住滚垫，脚跟固定。"),
    E("大腿内外侧机", "腿", ["臀"], ["内收肌群", "臀中肌", "阔筋膜张肌"], "adduction",
      "调整腿垫，骨盆贴垫，选择内收/外展模式。"),
    E("髋内收机", "腿", [], ["内收肌群"], "adduction",
      "坐稳，双腿贴垫，向中线夹紧。"),
    # 臀
    E("臀推机", "臀", ["腿"], ["臀大肌", "臀中肌", "腘绳肌"], "hip_thrust",
      "上背靠垫，滚筒垫压在髋部折痕，脚掌踩实。"),
    E("臀桥机", "臀", ["腿"], ["臀大肌", "腘绳肌", "竖脊肌"], "hip_thrust",
      "坐稳，背贴垫，双脚踩踏板，髋部顶起。"),
    E("臀腿挺身机-GHD", "臀", ["腿", "背"], ["腘绳肌", "臀大肌", "竖脊肌"], "glute_ham",
      "膝/髋垫位调好，脚踝固定，脊柱中立。"),
    E("后踢腿机", "臀", [], ["臀大肌", "臀中肌"], "kickback",
      "骨盆贴垫，工作腿膝/踝对齐。"),
    E("反向超伸机", "臀", ["腿", "背"], ["臀大肌", "腘绳肌", "竖脊肌"], "reverse_hyper",
      "上身贴垫，髋部在垫边缘，脚踝固定。"),
    E("髋外展机", "臀", ["腿"], ["臀中肌", "臀小肌", "阔筋膜张肌"], "abduction",
      "坐稳，骨盆贴垫，双腿向外展。"),
    E("硬拉机", "臀", ["腿", "背"], ["臀大肌", "腘绳肌", "竖脊肌", "斜方肌", "前臂肌群"], "deadlift",
      "脚掌踩实，屈髋握把，背部中立。"),
    # 核心
    E("腹肌训练凳", "核心", ["髋"], ["腹直肌", "腹斜肌", "髋屈肌"], "ab_bench",
      "调整下斜角度，双脚固定，下背贴垫。"),
    E("腹前屈训练机", "核心", [], ["腹直肌", "腹斜肌"], "ab_crunch",
      "调整座椅和胸垫，背部贴垫，腹部先收紧。"),
    E("分体式腹前屈机", "核心", [], ["腹直肌", "腹斜肌"], "ab_crunch",
      "两侧独立，先调好座位和胸垫，左右均衡。"),
    E("腹肌滑轨机", "核心", [], ["腹直肌", "腹斜肌"], "ab_crunch",
      "跪/坐稳，双手握把，腹部带动滑轨。"),
    E("躯干旋转机", "核心", ["背"], ["腹斜肌", "腹直肌", "竖脊肌"], "torso_rotation",
      "坐稳，骨盆固定，双手扶垫。"),
    # 有氧
    E("跑步机", "有氧", ["腿"], ["心肺", "下肢"], "cardio",
      "先走 3–5 分钟热身，再逐步加速。"),
    E("椭圆机", "有氧", ["全身"], ["心肺", "全身"], "cardio",
      "双脚踩稳踏板，先低阻力热身。"),
    E("动感单车", "有氧", ["腿", "臀"], ["心肺", "股四头肌", "臀大肌", "小腿"], "cardio",
      "调整座椅高度，膝盖微屈，先低阻力热身。"),
    E("爬楼机", "有氧", ["腿", "臀"], ["心肺", "股四头肌", "臀大肌", "小腿"], "cardio",
      "双脚踩稳踏板，身体直立，先慢速热身。"),
    # 全身
    E("史密斯架", "全身", ["胸", "背", "肩", "腿", "臀"], ["全身"], "smith",
      "先调好安全挂钩和杠铃高度，再按动作模式训练。"),
    E("龙门架", "全身", ["胸", "背", "肩", "臂", "腿", "核心"], ["全身"], "cable",
      "选择把手和滑轮高度，保持绳索张力。"),
    E("双滑轮训练器", "全身", ["胸", "背", "肩", "臂"], ["全身"], "cable",
      "两侧滑轮可独立调节，先调好高度和重量。"),
]

TEMPLATES = {
    "horizontal_push": {
        "steps": ["坐稳/躺稳，肩胛后缩下沉，双脚踩实。", "呼气推起，肘部保持微屈，顶端不要锁死。", "吸气控制回放，保持目标肌群张力。"],
        "safety": ["不要耸肩或让肘部过度外展。", "肩前侧疼痛时停止并减轻重量。"],
    },
    "incline_push": {
        "steps": ["坐稳，背部贴垫，肩胛后缩下沉。", "沿上胸方向推起，肘部微屈。", "控制回放，感受上胸拉长。"],
        "safety": ["不要让肩部前移或耸肩。", "角度过高会增加肩关节压力。"],
    },
    "decline_push": {
        "steps": ["坐稳/躺稳，握把在下胸位置。", "沿下胸方向推起，肘部微屈。", "控制回放，保持肩胛稳定。"],
        "safety": ["不要锁死肘关节。", "肩部不适时改用平板推胸。"],
    },
    "fly": {
        "steps": ["调整座椅，握把与胸线平齐，肘部微屈。", "用胸带动向中间夹紧，顶端停顿。", "控制打开，避免肩部过度后伸。"],
        "safety": ["不要用惯性甩动。", "肩前侧不适时缩小幅度。"],
    },
    "vertical_pull": {
        "steps": ["握距略宽于肩，先沉肩，再收紧核心。", "用肘部向下拉，拉至锁骨/上胸附近。", "控制回放，让背阔肌充分拉长。"],
        "safety": ["不要耸肩或用身体后仰借力。", "颈部保持中立。"],
    },
    "horizontal_pull": {
        "steps": ["胸部贴垫/坐稳，肩胛先稳定。", "肘部向后拉，肩胛后缩，拉向腹部/下胸。", "控制回放，保持背部张力。"],
        "safety": ["不要含胸或耸肩。", "避免用腰部前后摆动借力。"],
    },
    "pullover": {
        "steps": ["调整座椅，肩关节与转轴对齐，手臂微屈。", "用背阔肌带动，沿弧线向后/向下拉。", "控制回放，保持肋骨下沉。"],
        "safety": ["不要过度挺腰。", "肩关节不适时缩小幅度。"],
    },
    "back_extension": {
        "steps": ["髋部位于垫边缘，脚踝固定，脊柱中立。", "屈髋下放，感受腘绳肌拉长。", "臀腿发力回到身体成一直线，不要过伸。"],
        "safety": ["不要用腰部甩起。", "顶端不要过度后仰。"],
    },
    "shrug": {
        "steps": ["肩部置于垫下，双臂伸直。", "肩膀垂直向上提，顶端停顿。", "控制下放，不要转肩。"],
        "safety": ["不要屈肘借力。", "颈部保持中立。"],
    },
    "vertical_push": {
        "steps": ["坐稳，核心收紧，背部贴垫。", "向上推起，肘部位于手腕下方。", "控制下放，保持肩胛稳定。"],
        "safety": ["不要耸肩或过度挺腰。", "肘部不要完全锁死。"],
    },
    "lateral_raise": {
        "steps": ["调整座椅，肘部与转轴对齐，手臂微屈。", "用肘带动向侧上方抬起，至肩高附近。", "控制下放，保持张力。"],
        "safety": ["不要耸肩或甩动。", "重量以能控制为准。"],
    },
    "upright_row": {
        "steps": ["握距略宽于肩，杠铃贴近身体。", "肘部向上提，提至下胸/肩前。", "控制下放，保持躯干稳定。"],
        "safety": ["不要拉得过高或耸肩。", "肩部不适时改用侧平举。"],
    },
    "neck": {
        "steps": ["调整头垫，颈部中立。", "小幅度、慢速完成屈伸/侧屈。", "控制回正，不要猛拉。"],
        "safety": ["从小重量、小幅度开始。", "眩晕或疼痛时立即停止。"],
    },
    "curl": {
        "steps": ["上臂贴垫，肘部固定。", "弯举至顶峰，停顿一秒。", "控制离心，回到起始位。"],
        "safety": ["不要摆动身体借力。", "手腕保持中立。"],
    },
    "preacher_curl": {
        "steps": ["上臂完全贴垫，腋窝靠近垫顶。", "弯举至前臂接近垂直。", "控制下放，不要完全放松。"],
        "safety": ["不要用肩部代偿。", "肘部不要锁死。"],
    },
    "triceps_pushdown": {
        "steps": ["肘部固定在体侧，握把在胸腹之间。", "伸肘下压，顶端停顿。", "控制回放，保持肘部不动。"],
        "safety": ["不要用身体重量下压。", "肘部不要外扩。"],
    },
    "triceps_extension": {
        "steps": ["调整座椅，肘部与转轴对齐，上臂贴垫。", "伸肘，感受肱三头肌收缩。", "控制回放，保持上臂稳定。"],
        "safety": ["不要用肩部借力。", "肘部不适时减轻重量。"],
    },
    "forearm": {
        "steps": ["前臂贴垫，手腕悬空。", "手腕缓慢屈/伸，顶端停顿。", "控制回放，保持前臂固定。"],
        "safety": ["重量轻起步，避免手腕猛甩。", "腕部疼痛时停止。"],
    },
    "dip": {
        "steps": ["肩胛下沉，身体略前倾，核心收紧。", "屈肘下放至舒适深度。", "推起回到起始位，肘部微屈。"],
        "safety": ["不要耸肩或下放过深。", "肩前侧疼痛时停止。"],
    },
    "leg_extension": {
        "steps": ["调整座椅，膝关节与转轴对齐。", "伸膝至接近伸直，顶端停顿。", "控制下放，保持股四头肌张力。"],
        "safety": ["不要用惯性甩起。", "膝盖不适时缩小幅度。"],
    },
    "leg_curl": {
        "steps": ["调整膝轴与垫位，髋部贴垫。", "脚跟向臀部方向勾，顶端停顿。", "控制回放，保持腘绳肌张力。"],
        "safety": ["不要抬起髋部借力。", "膝盖不适时减轻重量。"],
    },
    "leg_press": {
        "steps": ["背部贴垫，双脚与髋同宽，膝盖对准脚尖。", "下放至可控深度，不要塌腰。", "脚掌蹬起，膝盖保持微屈。"],
        "safety": ["不要锁死膝盖。", "下放过深导致骨盆卷起时立即停止。"],
    },
    "squat_machine": {
        "steps": ["肩/背贴垫，脚掌踩实，核心收紧。", "屈髋屈膝下蹲，膝盖对准脚尖。", "蹬地站起，保持躯干稳定。"],
        "safety": ["膝盖不要内扣。", "不要用腰部代偿。"],
    },
    "calf": {
        "steps": ["前脚掌踩稳踏板，脚跟悬空。", "脚跟抬高至顶峰，停顿。", "控制下放，感受小腿拉长。"],
        "safety": ["不要弹震。", "踝关节不适时缩小幅度。"],
    },
    "tibialis": {
        "steps": ["脚背勾住滚垫，脚跟固定。", "脚背向小腿方向勾起。", "控制回放，保持慢速。"],
        "safety": ["从小幅度开始。", "踝关节疼痛时停止。"],
    },
    "adduction": {
        "steps": ["坐稳，骨盆贴垫，双腿贴垫。", "向中线夹紧或向外展开（按模式）。", "控制回放，保持骨盆稳定。"],
        "safety": ["不要用惯性甩腿。", "髋部不适时缩小幅度。"],
    },
    "hip_thrust": {
        "steps": ["上背靠垫，脚掌踩实，髋部贴住滚筒垫。", "伸髋顶起，顶端夹臀，肋骨下沉。", "控制下放，保持臀部张力。"],
        "safety": ["不要用腰部反弓。", "顶端到大腿与地面平行即可。"],
    },
    "glute_ham": {
        "steps": ["调整膝/髋垫位，脚踝固定。", "屈膝或伸髋，按动作模式发力。", "控制回放，保持脊柱中立。"],
        "safety": ["不要甩动身体。", "下背不适时缩小幅度。"],
    },
    "kickback": {
        "steps": ["骨盆贴垫，工作腿膝/踝对齐。", "腿向后伸，顶端夹臀。", "控制回放，不要转动骨盆。"],
        "safety": ["不要用腰部代偿。", "幅度以骨盆稳定为准。"],
    },
    "reverse_hyper": {
        "steps": ["上身贴垫，髋部在垫边缘，腿自然下垂。", "臀腿发力抬腿，至与躯干成一直线。", "控制下放，不要甩腿。"],
        "safety": ["不要过度挺腰。", "颈椎保持中立。"],
    },
    "abduction": {
        "steps": ["坐稳，骨盆贴垫。", "双腿向外展开，顶端停顿。", "控制回放，保持骨盆稳定。"],
        "safety": ["不要用惯性甩腿。", "髋部不适时减轻重量。"],
    },
    "deadlift": {
        "steps": ["脚掌踩实，屈髋握把，背部中立。", "蹬地伸髋，杠铃贴近身体上升。", "控制下放，保持脊柱中立。"],
        "safety": ["不要圆背。", "顶端不要过度后仰。"],
    },
    "ab_crunch": {
        "steps": ["背贴垫，腹部先收紧。", "卷腹，让胸廓靠近骨盆。", "控制回放，不要拉脖子。"],
        "safety": ["不要用手拉头。", "下背不适时缩小幅度。"],
    },
    "ab_bench": {
        "steps": ["双脚固定，下背贴垫，腹部先收紧。", "卷起上身，呼气收紧腹肌。", "控制下放，不要借惯性。"],
        "safety": ["不要拉脖子。", "下背不适时减小下斜角度。"],
    },
    "torso_rotation": {
        "steps": ["坐稳，骨盆固定，双手扶垫。", "躯干缓慢旋转，控制幅度。", "回正，换另一侧。"],
        "safety": ["不要快速甩动。", "腰椎不适时缩小幅度。"],
    },
    "cardio": {
        "steps": ["先用低强度热身 3–5 分钟。", "保持目标心率，动作节奏稳定。", "结束前慢慢降速冷身。"],
        "safety": ["从低强度开始，循序渐进。", "胸闷、眩晕时立即停止。"],
    },
    "smith": {
        "steps": ["先调好安全挂钩和杠铃高度。", "按动作模式（推/蹲/拉）保持躯干稳定。", "控制回放，安全挂钩随时可用。"],
        "safety": ["不要省略安全挂钩。", "固定轨迹不适时改用自由重量。"],
    },
    "cable": {
        "steps": ["选择把手和滑轮高度，保持绳索张力。", "核心收紧，按目标动作推/拉/夹。", "控制回放，不要让配重片撞击。"],
        "safety": ["不要用惯性甩动。", "换把手前先降重量。"],
    },
    "cable_row": {
        "steps": ["坐稳，双脚踩实，胸部贴垫。", "肘部向后拉，肩胛后缩，拉向腹部。", "控制回放，保持背部张力。"],
        "safety": ["不要用腰部前后摆动借力。", "不要耸肩。"],
    },
    "free_weight": {
        "steps": ["调整器械/凳子，脚掌踩实，核心收紧。", "按目标动作控制下放和推起。", "全程保持脊柱中立。"],
        "safety": ["大重量时使用保护/同伴。", "动作变形时立即降重量。"],
    },
}

MUSCLE_CUES = {
    "胸大肌": "肩胛后缩下沉，用胸带动推起/夹紧，肘部不要过度外展。",
    "胸大肌上束": "把座椅调低或凳面调高，推起轨迹朝上胸方向。",
    "胸大肌下束": "把座椅调高或使用下斜角度，推起轨迹朝下胸方向。",
    "三角肌前束": "控制肘部角度，避免耸肩，推起时前束先发力。",
    "三角肌中束": "用肘带动侧抬，不要耸肩，顶端停顿。",
    "三角肌后束": "肩胛后缩，肘部略低于肩，向后拉/打开。",
    "肱三头肌": "最后三分之一行程主动伸肘，肘部固定在体侧。",
    "肱三头肌长头": "手臂举过头顶/向后伸展时，保持肘部朝前。",
    "肱二头肌": "肘部固定，弯举时不要摆动身体，顶峰收缩。",
    "肱肌": "保持掌心相对或旋后，控制离心。",
    "肱桡肌": "用锤式握法，手腕保持中立。",
    "背阔肌": "先沉肩，再用肘带动下拉/划船，避免耸肩。",
    "大圆肌": "肘部贴近身体，拉至下胸/腹部。",
    "菱形肌": "肩胛后缩夹紧，肘部向后。",
    "斜方肌": "肩胛骨向脊柱靠拢，不要耸肩。",
    "斜方肌中束": "肩胛骨向脊柱靠拢，保持胸口打开。",
    "斜方肌中下束": "先沉肩，再下拉，避免耸肩。",
    "斜方肌上束": "肩膀垂直向上耸，不要转圈。",
    "肩胛提肌": "肩膀垂直上提，颈部保持中立。",
    "竖脊肌": "脊柱中立，屈髋而不是弯腰，顶端不要过伸。",
    "臀大肌": "脚跟发力，顶端夹臀，肋骨下沉。",
    "臀中肌": "保持骨盆稳定，侧向/伸髋发力。",
    "臀小肌": "保持骨盆稳定，控制外展幅度。",
    "阔筋膜张肌": "外展时避免骨盆倾斜，控制回放。",
    "腘绳肌": "脚跟向臀部勾，髋部贴垫，控制离心。",
    "股四头肌": "膝盖对准脚尖，脚掌踩实，控制下放。",
    "内收肌": "大腿向中线夹紧，避免借力。",
    "内收肌群": "大腿向中线夹紧，骨盆保持稳定。",
    "腓肠肌": "膝盖伸直，脚跟抬高，顶端停顿。",
    "比目鱼肌": "膝盖微屈，脚跟抬高，慢放。",
    "胫骨前肌": "脚背向小腿勾起，控制回放。",
    "腹直肌": "卷腹而不是拉脖子，呼气收紧。",
    "腹斜肌": "旋转/侧屈时控制幅度，不要甩。",
    "髋屈肌": "腹部先收紧，避免用大腿前侧代偿。",
    "前臂屈肌": "手腕缓慢屈曲，前臂固定。",
    "前臂伸肌": "手腕缓慢伸展，前臂固定。",
    "前臂肌群": "手腕保持中立，握紧但不要死攥。",
    "胸锁乳突肌": "小幅度、慢速，避免猛拉。",
    "颈部伸肌": "小幅度、慢速，颈部不要后仰过度。",
    "心肺": "保持能说话的强度，循序渐进。",
    "下肢": "脚掌踩稳，膝盖对准脚尖。",
    "全身": "动作模式决定发力部位；先把姿势做稳，再逐渐加重量。",
}


def norm(value: str) -> str:
    return (
        value.lower()
        .replace(" ", "")
        .replace("　", "")
        .replace("-", "")
        .replace("_", "")
        .replace("（", "(")
        .replace("）", ")")
    )


def base_name(stem: str) -> str:
    return re.sub(r"[1-9]$", "", re.sub(r"_260$", "", stem))


def load_old():
    rows = json.loads(OLD_CATALOG.read_text(encoding="utf-8"))["equipment"]
    by_slug = {row["slug"]: row for row in rows}
    by_name = {}
    for row in rows:
        for name in [row["name_zh"]] + list(row.get("aliases") or []):
            by_name.setdefault(norm(name), row)
    return rows, by_slug, by_name


def resolve_entry(seed, by_slug, by_name):
    name = seed["name"]
    if name in NEW_TYPES:
        slug, group = NEW_TYPES[name]
        return slug, group, None
    if name in MANUAL_OLD:
        old = by_slug[MANUAL_OLD[name]]
    else:
        old = by_name.get(norm(name))
    if old is None:
        raise KeyError(f"no old catalog entry for {name}")
    return old["slug"], old["exercise_group"], old


def main():
    old_rows, by_slug, by_name = load_old()
    if len(SEED) != 70:
        raise SystemExit(f"expected 70 seed entries, got {len(SEED)}")

    files = sorted(p for p in IMAGE_SOURCE.iterdir() if p.is_file())
    groups = {}
    for path in files:
        groups.setdefault(base_name(path.stem), []).append(path)
    if len(groups) != 70:
        raise SystemExit(f"expected 70 image groups, got {len(groups)}")

    seed_names = {entry["name"] for entry in SEED}
    missing_images = sorted(seed_names - set(groups))
    extra_images = sorted(set(groups) - seed_names)
    if missing_images or extra_images:
        raise SystemExit(
            f"image/name mismatch missing={missing_images} extra={extra_images}"
        )

    OUT_IMAGES.mkdir(parents=True, exist_ok=True)
    catalog = []
    guides = {}
    manifest = {}

    for entry in SEED:
        slug, group, old = resolve_entry(entry, by_slug, by_name)
        paths = sorted(groups[entry["name"]], key=lambda p: p.name)
        image_urls = []
        image_files = []
        for index, path in enumerate(paths, start=1):
            filename = f"{slug}-{index}.jpg"
            with Image.open(path) as image:
                image = image.convert("RGB")
                image.thumbnail((1000, 1000), Image.Resampling.LANCZOS)
                image.save(
                    OUT_IMAGES / filename,
                    format="JPEG",
                    quality=82,
                    optimize=True,
                )
            image_files.append(filename)
            image_urls.append(f"/media/equipment-catalog/{filename}")

        aliases = set()
        name_en = None
        if old:
            aliases.update(old.get("aliases") or [])
            aliases.add(old["name_zh"])
            name_en = old.get("name_en")
        aliases.discard(entry["name"])
        aliases.discard(slug)

        catalog.append(
            {
                "slug": slug,
                "name_zh": entry["name"],
                "name_en": name_en,
                "category": entry_category(entry, slug, old),
                "body_part": entry["body_part"],
                "secondary_body_parts": entry["secondary"],
                "target_muscles": entry["targets"],
                "exercise_group": group,
                "exercise_slugs": EXTRA_EXERCISE_SLUGS.get(slug),
                "image_urls": image_urls,
                "universal": False,
                "aliases": sorted(aliases),
            }
        )
        manifest[slug] = image_files

        template = TEMPLATES[entry["template"]]
        cues = {}
        for muscle in entry["targets"]:
            cues[muscle] = entry["cues"].get(
                muscle,
                MUSCLE_CUES.get(
                    muscle, "保持动作稳定，控制离心，避免借力。"
                ),
            )
        guides[slug] = {
            "setup": entry["setup"],
            "steps": template["steps"],
            "cues": cues,
            "safety": template["safety"],
        }

    catalog.sort(key=lambda row: (order_body_part(row["body_part"]), row["name_zh"]))
    OUT_CATALOG.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
    )
    OUT_GUIDES.write_text(
        json.dumps(guides, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
    )
    OUT_MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
    )

    ios_catalog = [
        {
            "slug": row["slug"],
            "name_zh": row["name_zh"],
            "name_en": row["name_en"],
            "category": row["category"],
            "body_part": row["body_part"],
            "secondary_body_parts": row["secondary_body_parts"],
            "target_muscles": row["target_muscles"],
            "exercise_group": row["exercise_group"],
            "exercise_slugs": row["exercise_slugs"],
            "image_urls": row["image_urls"],
            "universal": False,
            "aliases": row["aliases"],
        }
        for row in catalog
    ]
    OUT_IOS_CATALOG.write_text(
        json.dumps(ios_catalog, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
    )
    OUT_IOS_GUIDES.write_text(
        json.dumps(guides, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
    )

    print(f"catalog={len(catalog)} guides={len(guides)} images={len(files)}")
    print(f"wrote {OUT_CATALOG}")
    print(f"wrote {OUT_GUIDES}")
    print(f"wrote {OUT_IOS_CATALOG}")
    print(f"wrote {OUT_IOS_GUIDES}")
    print(f"optimized images -> {OUT_IMAGES}")


def entry_category(entry, slug, old):
    if entry["body_part"] == "有氧":
        return "cardio"
    if slug in {"cable_crossover", "dual_pulley", "cable_row"}:
        return "cable"
    if slug == "smith_machine":
        return "multi"
    if slug in {"bench_press", "incline_bench", "squat_rack"}:
        return "free_weight"
    return "machine"


def order_body_part(value):
    order = ["胸", "背", "肩", "臂", "腿", "臀", "核心", "有氧", "全身"]
    return order.index(value) if value in order else len(order)


if __name__ == "__main__":
    main()
