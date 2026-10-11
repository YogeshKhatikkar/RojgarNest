# seed_schemes.py
"""
One-time seeder for the `schemes` collection.
Run:  python seed_schemes.py
Idempotent — safe to run multiple times (uses upsert).
"""

import asyncio
import logging
from datetime import datetime

from app.db.connection import get_db

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("seed_schemes")


SCHEMES = [
    # ============================================================
    # CENTRAL SCHEMES
    # ============================================================
    {
        "scheme_id": "pm_kisan",
        "scheme_name": "PM-KISAN",
        "scheme_name_hindi": "प्रधानमंत्री किसान सम्मान निधि",
        "short_description": "Financial assistance of ₹6,000/year to small farmers",
        "short_description_hindi": "छोटे किसानों को ₹6,000/वर्ष की वित्तीय सहायता",
        "level": "central",
        "state": None,
        "category": "agriculture",
        "full_description": (
            "Pradhan Mantri Kisan Samman Nidhi (PM-KISAN) is a Central Sector "
            "Scheme providing income support to all landholding farmers' families. "
            "₹6000 per year is released in three equal installments of ₹2000 each."
        ),
        "full_description_hindi": (
            "प्रधानमंत्री किसान सम्मान निधि (PM-KISAN) एक केंद्रीय क्षेत्र की योजना है "
            "जो देश के सभी भूमिधारक किसान परिवारों को आय सहायता प्रदान करती है। "
            "₹2000 की तीन समान किस्तों में प्रति वर्ष ₹6000 जारी की जाती है।"
        ),
        "benefits": [
            {"title": "Direct Income Support",
             "description": "₹6,000 per year in 3 installments",
             "amount": "₹6,000/year", "type": "financial"},
            {"title": "Direct Benefit Transfer",
             "description": "Amount credited directly to bank account",
             "amount": None, "type": "financial"},
        ],
        "eligibility": {
            "age_min": 18, "age_max": None, "gender": None,
            "income_limit": 300000, "category": None,
            "education_level": None, "occupation": "Farmer",
            "domicile_state": None, "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": (
            "• किसान परिवार के पास खेती योग्य भूमि होनी चाहिए\n"
            "• आयु 18 वर्ष या अधिक होनी चाहिए\n"
            "• आधार कार्ड आवश्यक है\n"
            "• बैंक खाता आवश्यक है"
        ),
        "target_beneficiaries": ["Small and marginal farmers", "Landholding farmer families"],
        "target_beneficiaries_hindi": ["छोटे और सीमांत किसान", "भूमिधारक किसान परिवार"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड", "required": True, "description": None},
            {"name": "Land Records", "name_hindi": "भूमि रिकॉर्ड", "required": True, "description": None},
            {"name": "Bank Passbook", "name_hindi": "बैंक पासबुक", "required": True, "description": None},
            {"name": "Mobile Number", "name_hindi": "मोबाइल नंबर", "required": True, "description": None},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit PM-KISAN Portal",
             "title_hindi": "PM-KISAN पोर्टल पर जाएं",
             "description": "Go to pmkisan.gov.in and click on 'New Farmer Registration'",
             "description_hindi": "pmkisan.gov.in पर जाएं और 'नया किसान पंजीकरण' पर क्लिक करें"},
            {"step_number": 2, "title": "Fill Application Form",
             "title_hindi": "आवेदन पत्र भरें",
             "description": "Enter your Aadhaar number, mobile number and other details",
             "description_hindi": "अपना आधार नंबर, मोबाइल नंबर और अन्य विवरण दर्ज करें"},
            {"step_number": 3, "title": "Upload Documents",
             "title_hindi": "दस्तावेज अपलोड करें",
             "description": "Upload scanned copies of required documents",
             "description_hindi": "आवश्यक दस्तावेजों की स्कैन की गई प्रतियां अपलोड करें"},
            {"step_number": 4, "title": "Submit Application",
             "title_hindi": "आवेदन जमा करें",
             "description": "Review and submit your application",
             "description_hindi": "अपने आवेदन की समीक्षा करें और जमा करें"},
        ],
        "application_mode": "online",
        "contact_info": {
            "helpline": "155261 / 011-24300606",
            "email": "pmkisan-ict@gov.in",
            "website": "https://pmkisan.gov.in",
            "office_address": None,
        },
        "official_website": "https://pmkisan.gov.in",
        "apply_link": "https://pmkisan.gov.in/RegistrationFormUpdated.aspx",
        "has_application_fee": False,
        "application_fee": 0,
        "fee_details_hindi": None,
        "icon": "🌾",
        "color": "green",
        "is_featured": True,
        "priority": 100,
        "tags": ["farmer", "agriculture", "income support", "किसान"],
        "search_keywords": ["pm-kisan", "pmkisan", "kisan", "farmer", "agriculture"],
    },

    {
        "scheme_id": "ayushman_bharat",
        "scheme_name": "Ayushman Bharat (PM-JAY)",
        "scheme_name_hindi": "आयुष्मान भारत (PM-JAY)",
        "short_description": "Health insurance cover of ₹5 lakh per family per year",
        "short_description_hindi": "प्रति परिवार प्रति वर्ष ₹5 लाख का स्वास्थ्य बीमा",
        "level": "central",
        "state": None,
        "category": "health",
        "full_description": (
            "Ayushman Bharat Pradhan Mantri Jan Arogya Yojana (PM-JAY) is the "
            "largest health assurance scheme in the world providing ₹5 lakhs per "
            "family per year for secondary and tertiary care hospitalization."
        ),
        "full_description_hindi": (
            "आयुष्मान भारत प्रधानमंत्री जन आरोग्य योजना (PM-JAY) दुनिया की सबसे बड़ी "
            "स्वास्थ्य बीमा योजना है जो प्रति परिवार प्रति वर्ष ₹5 लाख का स्वास्थ्य कवर "
            "प्रदान करती है।"
        ),
        "benefits": [
            {"title": "Health Coverage", "description": "₹5 lakh per family per year",
             "amount": "₹5,00,000", "type": "financial"},
            {"title": "Cashless Treatment",
             "description": "Cashless treatment at empanelled hospitals",
             "amount": None, "type": "service"},
            {"title": "Pre-existing Diseases", "description": "Covered from day one",
             "amount": None, "type": "service"},
        ],
        "eligibility": {
            "age_min": None, "age_max": None, "gender": None,
            "income_limit": 100000, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": None, "disability_required": False,
            "bpl_required": True, "aadhaar_required": True,
        },
        "eligibility_details_hindi": (
            "• SECC 2011 डेटा में शामिल परिवार\n"
            "• ग्रामीण क्षेत्रों में BPL परिवार\n"
            "• शहरी क्षेत्रों में श्रमिक परिवार\n"
            "• आयु या लिंग की कोई सीमा नहीं"
        ),
        "target_beneficiaries": ["BPL families", "Low income households", "Vulnerable communities"],
        "target_beneficiaries_hindi": ["BPL परिवार", "कम आय वाले परिवार", "कमजोर समुदाय"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड", "required": True, "description": None},
            {"name": "Ration Card", "name_hindi": "राशन कार्ड", "required": True, "description": None},
            {"name": "Income Certificate", "name_hindi": "आय प्रमाण पत्र", "required": True, "description": None},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Check Eligibility",
             "title_hindi": "पात्रता जांचें",
             "description": "Visit pmjay.gov.in and check if your family is eligible",
             "description_hindi": "pmjay.gov.in पर जाएं और जांचें कि आपका परिवार पात्र है या नहीं"},
            {"step_number": 2, "title": "Get Ayushman Card",
             "title_hindi": "आयुष्मान कार्ड प्राप्त करें",
             "description": "Visit nearest CSC or empanelled hospital to get your card",
             "description_hindi": "अपना कार्ड प्राप्त करने के लिए निकटतम CSC या सूचीबद्ध अस्पताल पर जाएं"},
            {"step_number": 3, "title": "Avail Benefits",
             "title_hindi": "लाभ प्राप्त करें",
             "description": "Show your card at empanelled hospitals for free treatment",
             "description_hindi": "मुफ्त इलाज के लिए सूचीबद्ध अस्पतालों में अपना कार्ड दिखाएं"},
        ],
        "application_mode": "online",
        "contact_info": {
            "helpline": "14555 / 1800-111-565",
            "email": "pmjay@nha.gov.in",
            "website": "https://pmjay.gov.in",
            "office_address": None,
        },
        "official_website": "https://pmjay.gov.in",
        "apply_link": "https://pmjay.gov.in/am-i-eligible",
        "has_application_fee": False,
        "application_fee": 0,
        "fee_details_hindi": None,
        "icon": "🏥",
        "color": "teal",
        "is_featured": True,
        "priority": 95,
        "tags": ["health", "insurance", "hospital", "स्वास्थ्य"],
        "search_keywords": ["ayushman", "pmjay", "health", "insurance"],
    },

    {
        "scheme_id": "pm_awas_yojana",
        "scheme_name": "Pradhan Mantri Awas Yojana",
        "scheme_name_hindi": "प्रधानमंत्री आवास योजना",
        "short_description": "Affordable housing for all by providing financial assistance",
        "short_description_hindi": "वित्तीय सहायता प्रदान करके सभी के लिए किफायती आवास",
        "level": "central",
        "state": None,
        "category": "housing",
        "full_description": (
            "Pradhan Mantri Awas Yojana (PMAY) aims to provide affordable housing "
            "to the urban and rural poor. The scheme provides central assistance "
            "to eligible beneficiaries for construction of houses."
        ),
        "full_description_hindi": (
            "प्रधानमंत्री आवास योजना (PMAY) का उद्देश्य शहरी और ग्रामीण गरीबों को "
            "किफायती आवास प्रदान करना है।"
        ),
        "benefits": [
            {"title": "Financial Assistance",
             "description": "Up to ₹2.67 lakh for house construction",
             "amount": "₹2,67,000", "type": "financial"},
            {"title": "Subsidized Loan",
             "description": "Interest subsidy on home loans",
             "amount": None, "type": "financial"},
        ],
        "eligibility": {
            "age_min": None, "age_max": None, "gender": None,
            "income_limit": 1800000, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": None, "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": (
            "• आवेदक के पास पक्का घर नहीं होना चाहिए\n"
            "• EWS: ₹3 लाख तक वार्षिक आय\n"
            "• LIG: ₹3-6 लाख वार्षिक आय\n"
            "• MIG: ₹6-18 लाख वार्षिक आय"
        ),
        "target_beneficiaries": ["EWS families", "LIG families", "MIG families", "Slum dwellers"],
        "target_beneficiaries_hindi": ["EWS परिवार", "LIG परिवार", "MIG परिवार", "झुग्गी-झोपड़ी निवासी"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड", "required": True, "description": None},
            {"name": "Income Certificate", "name_hindi": "आय प्रमाण पत्र", "required": True, "description": None},
            {"name": "Bank Account Details", "name_hindi": "बैंक खाता विवरण", "required": True, "description": None},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Official Portal",
             "title_hindi": "आधिकारिक पोर्टल पर जाएं",
             "description": "Go to pmaymis.gov.in for urban or pmayg.nic.in for rural",
             "description_hindi": "शहरी के लिए pmaymis.gov.in या ग्रामीण के लिए pmayg.nic.in पर जाएं"},
            {"step_number": 2, "title": "Select Citizen Assessment",
             "title_hindi": "नागरिक मूल्यांकन चुनें",
             "description": "Click on 'Citizen Assessment' and fill the form",
             "description_hindi": "'नागरिक मूल्यांकन' पर क्लिक करें और फॉर्म भरें"},
            {"step_number": 3, "title": "Submit with Documents",
             "title_hindi": "दस्तावेजों के साथ जमा करें",
             "description": "Upload required documents and submit",
             "description_hindi": "आवश्यक दस्तावेज अपलोड करें और जमा करें"},
        ],
        "application_mode": "online",
        "contact_info": {
            "helpline": "011-23060484",
            "email": "pmaymis@gov.in",
            "website": "https://pmaymis.gov.in",
            "office_address": None,
        },
        "official_website": "https://pmaymis.gov.in",
        "apply_link": "https://pmaymis.gov.in/Open/Find_A_Beneficiary.aspx",
        "has_application_fee": False,
        "application_fee": 0,
        "fee_details_hindi": None,
        "icon": "🏠",
        "color": "orange",
        "is_featured": True,
        "priority": 90,
        "tags": ["housing", "awas", "home loan", "आवास"],
        "search_keywords": ["pmay", "awas", "housing", "home"],
    },

    # ============================================================
    # STATE SCHEMES
    # ============================================================
    {
        "scheme_id": "mp_ladli_behna",
        "scheme_name": "Mukhyamantri Ladli Behna Yojana",
        "scheme_name_hindi": "मुख्यमंत्री लाड़ली बहना योजना",
        "short_description": "Financial assistance of ₹1,250/month to women",
        "short_description_hindi": "महिलाओं को ₹1,250/माह की वित्तीय सहायता",
        "level": "state",
        "state": "Madhya Pradesh",
        "category": "women_child",
        "full_description": (
            "Mukhyamantri Ladli Behna Yojana is a scheme by the Madhya Pradesh "
            "government to provide ₹1,250 per month to women aged 21-60 years."
        ),
        "full_description_hindi": (
            "मुख्यमंत्री लाड़ली बहना योजना मध्य प्रदेश सरकार की एक योजना है जो "
            "21-60 वर्ष की आयु की महिलाओं को ₹1,250 प्रति माह प्रदान करती है।"
        ),
        "benefits": [
            {"title": "Monthly Assistance",
             "description": "₹1,250 per month directly to bank account",
             "amount": "₹1,250/month", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 21, "age_max": 60, "gender": "female",
            "income_limit": 250000, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": "Madhya Pradesh", "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": (
            "• मध्य प्रदेश की मूल निवासी महिला\n"
            "• आयु 21-60 वर्ष\n"
            "• परिवार की वार्षिक आय ₹2.5 लाख से कम\n"
            "• आधार कार्ड और बैंक खाता आवश्यक"
        ),
        "target_beneficiaries": ["Women aged 21-60", "Madhya Pradesh residents"],
        "target_beneficiaries_hindi": ["21-60 वर्ष की महिलाएं", "मध्य प्रदेश निवासी"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड", "required": True, "description": None},
            {"name": "Domicile Certificate", "name_hindi": "मूल निवास प्रमाण पत्र", "required": True, "description": None},
            {"name": "Income Certificate", "name_hindi": "आय प्रमाण पत्र", "required": True, "description": None},
            {"name": "Bank Passbook", "name_hindi": "बैंक पासबुक", "required": True, "description": None},
            {"name": "Samagra ID", "name_hindi": "समग्र आईडी", "required": True, "description": None},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Camp or Portal",
             "title_hindi": "कैंप या पोर्टल पर जाएं",
             "description": "Visit designated camps or cmladlibahna.mp.gov.in",
             "description_hindi": "निर्धारित कैंपों या cmladlibahna.mp.gov.in पर जाएं"},
            {"step_number": 2, "title": "Fill Application Form",
             "title_hindi": "आवेदन पत्र भरें",
             "description": "Fill the application form with required details",
             "description_hindi": "आवश्यक विवरण के साथ आवेदन पत्र भरें"},
            {"step_number": 3, "title": "Submit with Documents",
             "title_hindi": "दस्तावेजों के साथ जमा करें",
             "description": "Submit form with all required documents",
             "description_hindi": "सभी आवश्यक दस्तावेजों के साथ फॉर्म जमा करें"},
        ],
        "application_mode": "online",
        "contact_info": {
            "helpline": "0755-2555999",
            "email": None,
            "website": "https://cmladlibahna.mp.gov.in",
            "office_address": None,
        },
        "official_website": "https://cmladlibahna.mp.gov.in",
        "apply_link": None,
        "has_application_fee": False,
        "application_fee": 0,
        "fee_details_hindi": None,
        "icon": "👩",
        "color": "pink",
        "is_featured": True,
        "priority": 85,
        "tags": ["women", "mp", "महिला", "मध्य प्रदेश"],
        "search_keywords": ["ladli behna", "mp", "women", "ladli"],
    },
]


async def seed():
    logger.info("=" * 60)
    logger.info("🌱 SEEDING SCHEMES COLLECTION")
    logger.info("=" * 60)

    db = await get_db()
    schemes_col = db["schemes"]
    apps_col = db["applications"]

    # ---------- Indexes ----------
    try:
        await schemes_col.create_index("scheme_id", unique=True)
        await schemes_col.create_index("level")
        await schemes_col.create_index("state")
        await schemes_col.create_index("category")
        await schemes_col.create_index("is_featured")
        await schemes_col.create_index("is_active")
        await schemes_col.create_index("priority")
        logger.info("✅ schemes indexes created")

        await apps_col.create_index([
            ("application_type", 1), ("user_email", 1)
        ])
        await apps_col.create_index([
            ("application_type", 1),
            ("scheme_id", 1),
            ("user_email", 1),
        ])
        logger.info("✅ applications indexes created")
    except Exception as e:
        logger.warning(f"Index creation warning: {e}")

    # ---------- Upsert each scheme ----------
    inserted = 0
    updated = 0

    for s in SCHEMES:
        s["is_active"] = True
        s["created_at"] = datetime.utcnow()
        s["updated_at"] = datetime.utcnow()

        result = await schemes_col.update_one(
            {"scheme_id": s["scheme_id"]},
            {
                "$set": s,
                "$setOnInsert": {"created_at": datetime.utcnow()},
            },
            upsert=True,
        )

        if result.upserted_id:
            inserted += 1
            logger.info(f"  ➕ Inserted: {s['scheme_id']}")
        else:
            updated += 1
            logger.info(f"  ♻️  Updated: {s['scheme_id']}")

    total = await schemes_col.count_documents({})

    logger.info("=" * 60)
    logger.info(f"✅ SEEDING COMPLETE")
    logger.info(f"   Inserted: {inserted}")
    logger.info(f"   Updated:  {updated}")
    logger.info(f"   Total in DB: {total}")
    logger.info("=" * 60)

    # ---------- Verify ----------
    pk = await schemes_col.find_one({"scheme_id": "pm_kisan"})
    if pk:
        logger.info(f"✅ Verified: pm_kisan exists (name={pk.get('scheme_name')})")
    else:
        logger.error("❌ VERIFY FAILED: pm_kisan NOT FOUND!")

    return {"inserted": inserted, "updated": updated, "total": total}


if __name__ == "__main__":
    asyncio.run(seed())