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
        "full_description": "Ayushman Bharat Pradhan Mantri Jan Arogya Yojana (PM-JAY) is the largest health assurance scheme in the world which aims at providing a health cover of ₹5 lakhs per family per year for secondary and tertiary care hospitalization.",
        "full_description_hindi": "आयुष्मान भारत प्रधानमंत्री जन आरोग्य योजना (PM-JAY) दुनिया की सबसे बड़ी स्वास्थ्य बीमा योजना है जिसका उद्देश्य माध्यमिक और तृतीयक देखभाल अस्पताल में भर्ती के लिए प्रति परिवार प्रति वर्ष ₹5 लाख का स्वास्थ्य कवर प्रदान करना है।",
        "benefits": [
            {"title": "Health Coverage", "description": "₹5 lakh per family per year", "amount": "₹5,00,000", "type": "financial"},
            {"title": "Cashless Treatment", "description": "Cashless treatment at empanelled hospitals", "type": "service"},
            {"title": "Pre-existing Diseases", "description": "Covered from day one", "type": "service"},
        ],
        "eligibility": {
            "age_min": None, "age_max": None, "gender": None,
            "income_limit": 100000, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": None, "disability_required": False,
            "bpl_required": True, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• SECC 2011 डेटा में शामिल परिवार\n• ग्रामीण क्षेत्रों में BPL परिवार\n• शहरी क्षेत्रों में श्रमिक परिवार\n• आयु या लिंग की कोई सीमा नहीं",
        "target_beneficiaries": ["BPL families", "Low income households", "Vulnerable communities"],
        "target_beneficiaries_hindi": ["BPL परिवार", "कम आय वाले परिवार", "कमजोर समुदाय"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Ration Card", "name_hindi": "राशन कार्ड"},
            {"name": "Income Certificate", "name_hindi": "आय प्रमाण पत्र"},
            {"name": "SECC Data Verification", "name_hindi": "SECC डेटा सत्यापन"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Check Eligibility", "title_hindi": "पात्रता जांचें", "description": "Visit pmjay.gov.in and check if your family is eligible", "description_hindi": "pmjay.gov.in पर जाएं और जांचें कि आपका परिवार पात्र है या नहीं"},
            {"step_number": 2, "title": "Get Ayushman Card", "title_hindi": "आयुष्मान कार्ड प्राप्त करें", "description": "Visit nearest CSC or empanelled hospital to get your card", "description_hindi": "अपना कार्ड प्राप्त करने के लिए निकटतम CSC या सूचीबद्ध अस्पताल पर जाएं"},
            {"step_number": 3, "title": "Avail Benefits", "title_hindi": "लाभ प्राप्त करें", "description": "Show your card at empanelled hospitals for free treatment", "description_hindi": "मुफ्त इलाज के लिए सूचीबद्ध अस्पतालों में अपना कार्ड दिखाएं"},
        ],
        "application_mode": "online",
        "contact_info": {"helpline": "14555 / 1800-111-565", "email": "pmjay@nha.gov.in", "website": "https://pmjay.gov.in", "office_address": None},
        "official_website": "https://pmjay.gov.in",
        "apply_link": "https://pmjay.gov.in/am-i-eligible",
        "has_application_fee": False,
        "application_fee": 0,
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
        "full_description": "Pradhan Mantri Awas Yojana (PMAY) aims to provide affordable housing to the urban and rural poor. The scheme provides central assistance to eligible beneficiaries for construction of houses.",
        "full_description_hindi": "प्रधानमंत्री आवास योजना (PMAY) का उद्देश्य शहरी और ग्रामीण गरीबों को किफायती आवास प्रदान करना है। यह योजना पात्र लाभार्थियों को घरों के निर्माण के लिए केंद्रीय सहायता प्रदान करती है।",
        "benefits": [
            {"title": "Financial Assistance", "description": "Up to ₹2.67 lakh for house construction", "amount": "₹2,67,000", "type": "financial"},
            {"title": "Subsidized Loan", "description": "Interest subsidy on home loans", "type": "financial"},
        ],
        "eligibility": {
            "age_min": None, "age_max": None, "gender": None,
            "income_limit": 1800000, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": None, "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• आवेदक के पास पक्का घर नहीं होना चाहिए\n• EWS: ₹3 लाख तक वार्षिक आय\n• LIG: ₹3-6 लाख वार्षिक आय\n• MIG: ₹6-18 लाख वार्षिक आय",
        "target_beneficiaries": ["EWS families", "LIG families", "MIG families", "Slum dwellers"],
        "target_beneficiaries_hindi": ["EWS परिवार", "LIG परिवार", "MIG परिवार", "झुग्गी-झोपड़ी निवासी"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Income Certificate", "name_hindi": "आय प्रमाण पत्र"},
            {"name": "Bank Account Details", "name_hindi": "बैंक खाता विवरण"},
            {"name": "Affidavit (No Pucca House)", "name_hindi": "शपथ पत्र (पक्का घर नहीं)"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Official Portal", "title_hindi": "आधिकारिक पोर्टल पर जाएं", "description": "Go to pmaymis.gov.in for urban or pmayg.nic.in for rural", "description_hindi": "शहरी के लिए pmaymis.gov.in या ग्रामीण के लिए pmayg.nic.in पर जाएं"},
            {"step_number": 2, "title": "Select Citizen Assessment", "title_hindi": "नागरिक मूल्यांकन चुनें", "description": "Click on 'Citizen Assessment' and fill the form", "description_hindi": "'नागरिक मूल्यांकन' पर क्लिक करें और फॉर्म भरें"},
            {"step_number": 3, "title": "Submit with Documents", "title_hindi": "दस्तावेजों के साथ जमा करें", "description": "Upload required documents and submit", "description_hindi": "आवश्यक दस्तावेज अपलोड करें और जमा करें"},
        ],
        "application_mode": "online",
        "contact_info": {"helpline": "011-23060484", "email": "pmaymis@gov.in", "website": "https://pmaymis.gov.in", "office_address": None},
        "official_website": "https://pmaymis.gov.in",
        "apply_link": "https://pmaymis.gov.in/Open/Find_A_Beneficiary.aspx",
        "has_application_fee": False,
        "application_fee": 0,
        "icon": "🏠",
        "color": "orange",
        "is_featured": True,
        "priority": 90,
        "tags": ["housing", "awas", "home loan", "आवास"],
        "search_keywords": ["pmay", "awas", "housing", "home"],
    },
    
    {
        "scheme_id": "pm_mudra",
        "scheme_name": "Pradhan Mantri MUDRA Yojana",
        "scheme_name_hindi": "प्रधानमंत्री मुद्रा योजना",
        "short_description": "Loans up to ₹10 lakh for small businesses",
        "short_description_hindi": "छोटे व्यवसायों के लिए ₹10 लाख तक का ऋण",
        "level": "central",
        "state": None,
        "category": "entrepreneurship",
        "full_description": "Pradhan Mantri MUDRA Yojana (PMMY) provides loans up to ₹10 lakh to non-corporate, non-farm small/micro enterprises. These loans are given by Commercial Banks, RRBs, Small Finance Banks, MFIs and NBFCs.",
        "full_description_hindi": "प्रधानमंत्री मुद्रा योजना (PMMY) गैर-कॉर्पोरेट, गैर-कृषि लघु/सूक्ष्म उद्यमों को ₹10 लाख तक का ऋण प्रदान करती है। ये ऋण वाणिज्यिक बैंकों, RRBs, लघु वित्त बैंकों, MFIs और NBFCs द्वारा दिए जाते हैं।",
        "benefits": [
            {"title": "Shishu Loan", "description": "Up to ₹50,000 for startups", "amount": "₹50,000", "type": "financial"},
            {"title": "Kishore Loan", "description": "₹50,001 to ₹5 lakh for growing businesses", "amount": "₹50,001 - ₹5,00,000", "type": "financial"},
            {"title": "Tarun Loan", "description": "₹5 lakh to ₹10 lakh for established businesses", "amount": "₹5,00,001 - ₹10,00,000", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 18, "age_max": 65, "gender": None,
            "income_limit": None, "category": None,
            "education_level": None, "occupation": "Entrepreneur/Small Business",
            "domicile_state": None, "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• भारतीय नागरिक होना चाहिए\n• आयु 18-65 वर्ष के बीच\n• गैर-कृषि लघु/सूक्ष्म उद्यम\n• कोई डिफॉल्टर नहीं होना चाहिए",
        "target_beneficiaries": ["Small business owners", "Micro entrepreneurs", "Startup founders"],
        "target_beneficiaries_hindi": ["छोटे व्यवसाय मालिक", "सूक्ष्म उद्यमी", "स्टार्टअप संस्थापक"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "PAN Card", "name_hindi": "पैन कार्ड"},
            {"name": "Business Plan", "name_hindi": "व्यवसाय योजना"},
            {"name": "Bank Statement", "name_hindi": "बैंक विवरण"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Bank/NBFC", "title_hindi": "बैंक/NBFC पर जाएं", "description": "Visit any bank branch or NBFC that offers MUDRA loans", "description_hindi": "किसी भी बैंक शाखा या NBFC पर जाएं जो मुद्रा ऋण प्रदान करता है"},
            {"step_number": 2, "title": "Fill Application Form", "title_hindi": "आवेदन पत्र भरें", "description": "Fill the MUDRA loan application form with business details", "description_hindi": "व्यवसाय विवरण के साथ मुद्रा ऋण आवेदन पत्र भरें"},
            {"step_number": 3, "title": "Submit Documents", "title_hindi": "दस्तावेज जमा करें", "description": "Submit all required documents including business plan", "description_hindi": "व्यवसाय योजना सहित सभी आवश्यक दस्तावेज जमा करें"},
        ],
        "application_mode": "offline",
        "contact_info": {"helpline": "1800-180-1111", "email": "mudra@sidbi.in", "website": "https://www.mudra.org.in", "office_address": None},
        "official_website": "https://www.mudra.org.in",
        "apply_link": "https://www.mudra.org.in/Offerings",
        "has_application_fee": False,
        "application_fee": 0,
        "icon": "🚀",
        "color": "purple",
        "is_featured": True,
        "priority": 85,
        "tags": ["loan", "business", "entrepreneur", "व्यवसाय"],
        "search_keywords": ["mudra", "loan", "business"],
    },

    {
        "scheme_id": "sukanya_samriddhi",
        "scheme_name": "Sukanya Samriddhi Yojana",
        "scheme_name_hindi": "सुकन्या समृद्धि योजना",
        "short_description": "Small savings scheme for girl child education and marriage",
        "short_description_hindi": "बालिका शिक्षा और विवाह के लिए लघु बचत योजना",
        "level": "central",
        "state": None,
        "category": "women_child",
        "full_description": "Sukanya Samriddhi Yojana is a small deposit scheme for the girl child launched as a part of the Beti Bachao Beti Padhao campaign. The scheme encourages parents to build a fund for the future education and marriage expenses for their female child.",
        "full_description_hindi": "सुकन्या समृद्धि योजना बेटी बचाओ बेटी पढ़ाओ अभियान के एक भाग के रूप में शुरू की गई बालिका के लिए एक लघु जमा योजना है। यह योजना माता-पिता को अपनी बालिका की भविष्य की शिक्षा और विवाह के खर्चों के लिए एक कोष बनाने के लिए प्रोत्साहित करती है।",
        "benefits": [
            {"title": "High Interest Rate", "description": "Currently 8.2% per annum (highest among small savings)", "amount": "8.2% p.a.", "type": "financial"},
            {"title": "Tax Benefits", "description": "Tax deduction under Section 80C", "type": "financial"},
            {"title": "Maturity", "description": "Account matures after 21 years or on marriage after 18", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 0, "age_max": 10, "gender": "female",
            "income_limit": None, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": None, "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• बालिका की आयु 10 वर्ष से कम होनी चाहिए\n• अधिकतम 2 बालिकाओं के लिए खाता खोला जा सकता है\n• बालिका की ओर से माता-पिता या अभिभावक खाता खोल सकते हैं",
        "target_beneficiaries": ["Girl children below 10 years", "Parents of girl children"],
        "target_beneficiaries_hindi": ["10 वर्ष से कम आयु की बालिकाएं", "बालिकाओं के माता-पिता"],
        "required_documents": [
            {"name": "Birth Certificate of Girl Child", "name_hindi": "बालिका का जन्म प्रमाण पत्र"},
            {"name": "Aadhaar Card of Parent/Guardian", "name_hindi": "माता-पिता/अभिभावक का आधार कार्ड"},
            {"name": "Address Proof", "name_hindi": "पता प्रमाण"},
            {"name": "Photograph", "name_hindi": "फोटो"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Post Office/Bank", "title_hindi": "डाकघर/बैंक पर जाएं", "description": "Visit any authorized post office or bank branch", "description_hindi": "किसी भी अधिकृत डाकघर या बैंक शाखा पर जाएं"},
            {"step_number": 2, "title": "Fill Account Opening Form", "title_hindi": "खाता खोलने का फॉर्म भरें", "description": "Fill the Sukanya Samriddhi account opening form", "description_hindi": "सुकन्या समृद्धि खाता खोलने का फॉर्म भरें"},
            {"step_number": 3, "title": "Deposit Initial Amount", "title_hindi": "प्रारंभिक राशि जमा करें", "description": "Minimum ₹250 to open the account", "description_hindi": "खाता खोलने के लिए न्यूनतम ₹250"},
        ],
        "application_mode": "offline",
        "contact_info": {"helpline": "1800-11-1555", "website": "https://www.indiapost.gov.in"},
        "official_website": "https://www.indiapost.gov.in/Financial/Pages/Content/Post-Office-Saving-Schemes.aspx",
        "has_application_fee": False,
        "icon": "👧",
        "color": "pink",
        "is_featured": True,
        "priority": 85,
        "tags": ["girl child", "savings", "education", "बालिका"],
        "search_keywords": ["sukanya", "girl child", "savings"],
    },
    
    {
        "scheme_id": "pmjjby",
        "scheme_name": "PM Jeevan Jyoti Bima Yojana",
        "scheme_name_hindi": "प्रधानमंत्री जीवन ज्योति बीमा योजना",
        "short_description": "Life insurance cover of ₹2 lakh at ₹436/year",
        "short_description_hindi": "₹436/वर्ष पर ₹2 लाख का जीवन बीमा कवर",
        "level": "central",
        "state": None,
        "category": "insurance",
        "full_description": "Pradhan Mantri Jeevan Jyoti Bima Yojana (PMJJBY) is a government-backed life insurance scheme in India. It offers a renewable one-year life cover of ₹2 lakh to all savings bank account holders in the age group of 18 to 50 years.",
        "full_description_hindi": "प्रधानमंत्री जीवन ज्योति बीमा योजना (PMJJBY) भारत में सरकार समर्थित जीवन बीमा योजना है। यह 18 से 50 वर्ष की आयु वर्ग के सभी बचत बैंक खाताधारकों को ₹2 लाख का एक वर्षीय नवीकरणीय जीवन कवर प्रदान करती है।",
        "benefits": [
            {"title": "Life Cover", "description": "₹2 lakh in case of death due to any reason", "amount": "₹2,00,000", "type": "financial"},
            {"title": "Low Premium", "description": "Only ₹436 per year", "amount": "₹436/year", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 18, "age_max": 50, "gender": None,
            "income_limit": None, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": None, "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• आयु 18-50 वर्ष\n• बचत बैंक खाता होना चाहिए\n• आधार कार्ड आवश्यक\n• बैंक खाते से ऑटो-डेबिट सुविधा",
        "target_beneficiaries": ["Bank account holders", "Working professionals", "Self-employed individuals"],
        "target_beneficiaries_hindi": ["बैंक खाताधारक", "कामकाजी पेशेवर", "स्वरोजगार"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Bank Account", "name_hindi": "बैंक खाता"},
            {"name": "Nominee Details", "name_hindi": "नामांकित व्यक्ति विवरण"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Your Bank", "title_hindi": "अपने बैंक पर जाएं", "description": "Go to your bank branch and request PMJJBY enrollment", "description_hindi": "अपनी बैंक शाखा पर जाएं और PMJJBY नामांकन का अनुरोध करें"},
            {"step_number": 2, "title": "Fill Enrollment Form", "title_hindi": "नामांकन फॉर्म भरें", "description": "Fill the PMJJBY enrollment form with nominee details", "description_hindi": "नामांकित व्यक्ति विवरण के साथ PMJJBY नामांकन फॉर्म भरें"},
            {"step_number": 3, "title": "Auto-Debit Setup", "title_hindi": "ऑटो-डेबिट सेटअप", "description": "Enable auto-debit for annual premium", "description_hindi": "वार्षिक प्रीमियम के लिए ऑटो-डेबिट सक्षम करें"},
        ],
        "application_mode": "offline",
        "contact_info": {"helpline": "1800-180-1111", "website": "https://jansuraksha.gov.in"},
        "official_website": "https://jansuraksha.gov.in/PMJJBY.aspx",
        "has_application_fee": True,
        "application_fee": 436,
        "fee_details_hindi": "वार्षिक प्रीमियम: ₹436",
        "icon": "🛡️",
        "color": "indigo",
        "is_featured": False,
        "priority": 80,
        "tags": ["insurance", "life insurance", "बीमा"],
        "search_keywords": ["jeevan jyoti", "insurance", "life"],
    },
    
    {
        "scheme_id": "pmsby",
        "scheme_name": "PM Suraksha Bima Yojana",
        "scheme_name_hindi": "प्रधानमंत्री सुरक्षा बीमा योजना",
        "short_description": "Accident insurance cover of ₹2 lakh at ₹20/year",
        "short_description_hindi": "₹20/वर्ष पर ₹2 लाख का दुर्घटना बीमा कवर",
        "level": "central",
        "state": None,
        "category": "insurance",
        "full_description": "PMSBY offers accidental death and disability cover of ₹2 lakh at a premium of just ₹20 per year.",
        "full_description_hindi": "PMSBY केवल ₹20 प्रति वर्ष के प्रीमियम पर ₹2 लाख का दुर्घटना बीमा कवर प्रदान करती है।",
        "benefits": [
            {"title": "Accident Cover", "description": "₹2 lakh for accidental death", "amount": "₹2,00,000", "type": "financial"},
            {"title": "Disability Cover", "description": "Up to ₹2 lakh for disability", "amount": "₹2,00,000", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 18, "age_max": 70, "gender": None,
            "income_limit": None, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": None, "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• आयु 18-70 वर्ष\n• बचत बैंक खाता होना चाहिए",
        "target_beneficiaries": ["Bank account holders", "All adults"],
        "target_beneficiaries_hindi": ["बैंक खाताधारक", "सभी वयस्क"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Bank Account", "name_hindi": "बैंक खाता"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Your Bank", "title_hindi": "अपने बैंक पर जाएं", "description": "Request PMSBY enrollment", "description_hindi": "PMSBY नामांकन का अनुरोध करें"},
        ],
        "application_mode": "offline",
        "contact_info": {"helpline": "1800-180-1111", "website": "https://jansuraksha.gov.in"},
        "official_website": "https://jansuraksha.gov.in/PMSBY.aspx",
        "has_application_fee": True,
        "application_fee": 20,
        "fee_details_hindi": "वार्षिक प्रीमियम: ₹20",
        "icon": "🛡️",
        "color": "cyan",
        "is_featured": False,
        "priority": 80,
        "tags": ["accident", "insurance", "बीमा"],
        "search_keywords": ["suraksha bima", "accident", "insurance"],
    },
    
    {
        "scheme_id": "atal_pension",
        "scheme_name": "Atal Pension Yojana",
        "scheme_name_hindi": "अटल पेंशन योजना",
        "short_description": "Guaranteed pension of ₹1,000-₹5,000/month after 60",
        "short_description_hindi": "60 के बाद ₹1,000-₹5,000/माह की गारंटीड पेंशन",
        "level": "central",
        "state": None,
        "category": "pension",
        "full_description": "APY provides guaranteed minimum pension of ₹1,000 to ₹5,000 per month after age 60.",
        "full_description_hindi": "APY 60 वर्ष की आयु के बाद ₹1,000 से ₹5,000 प्रति माह की गारंटीड पेंशन प्रदान करती है।",
        "benefits": [
            {"title": "Guaranteed Pension", "description": "₹1,000 to ₹5,000 per month", "amount": "₹1,000-₹5,000/month", "type": "financial"},
            {"title": "Government Co-contribution", "description": "50% of contribution or ₹1,000/year", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 18, "age_max": 40, "gender": None,
            "income_limit": None, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": None, "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• आयु 18-40 वर्ष\n• बचत बैंक खाता होना चाहिए",
        "target_beneficiaries": ["Unorganized sector workers", "Self-employed", "All adults 18-40"],
        "target_beneficiaries_hindi": ["असंगठित क्षेत्र के श्रमिक", "स्वरोजगार", "18-40 वर्ष के सभी वयस्क"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Bank Account", "name_hindi": "बैंक खाता"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Your Bank", "title_hindi": "अपने बैंक पर जाएं", "description": "Request APY enrollment", "description_hindi": "APY नामांकन का अनुरोध करें"},
        ],
        "application_mode": "offline",
        "contact_info": {"helpline": "1800-110-069", "website": "https://www.npscra.nsdl.co.in"},
        "official_website": "https://www.npscra.nsdl.co.in/scheme-details.php",
        "has_application_fee": False,
        "icon": "👴",
        "color": "amber",
        "is_featured": False,
        "priority": 75,
        "tags": ["pension", "retirement", "पेंशन"],
        "search_keywords": ["atal pension", "pension", "retirement"],
    },
    
    {
        "scheme_id": "pm_svanidhi",
        "scheme_name": "PM SVANidhi",
        "scheme_name_hindi": "प्रधानमंत्री स्वनिधि योजना",
        "short_description": "Working capital loans for street vendors",
        "short_description_hindi": "रेहड़ी-पटरी विक्रेताओं के लिए कार्यशील पूंजी ऋण",
        "level": "central",
        "state": None,
        "category": "financial_inclusion",
        "full_description": "PM Street Vendor's AtmaNirbhar Nidhi provides working capital loans of ₹10,000 to ₹50,000 to street vendors.",
        "full_description_hindi": "PM स्वनिधि रेहड़ी-पटरी विक्रेताओं को ₹10,000 से ₹50,000 तक के कार्यशील पूंजी ऋण प्रदान करती है।",
        "benefits": [
            {"title": "Working Capital Loan", "description": "₹10,000 to ₹50,000", "amount": "₹10,000-₹50,000", "type": "financial"},
            {"title": "Interest Subsidy", "description": "7% interest subsidy on timely repayment", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 18, "age_max": None, "gender": None,
            "income_limit": None, "category": None,
            "education_level": None, "occupation": "Street Vendor",
            "domicile_state": None, "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• रेहड़ी-पटरी विक्रेता होना चाहिए\n• आयु 18 वर्ष या अधिक",
        "target_beneficiaries": ["Street vendors", "Small traders", "Hawkers"],
        "target_beneficiaries_hindi": ["रेहड़ी-पटरी विक्रेता", "छोटे व्यापारी", "फेरीवाले"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Vending Certificate", "name_hindi": "विक्रय प्रमाण पत्र"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Official Portal", "title_hindi": "आधिकारिक पोर्टल पर जाएं", "description": "Go to pmsvanidhi.mohua.gov.in", "description_hindi": "pmsvanidhi.mohua.gov.in पर जाएं"},
        ],
        "application_mode": "online",
        "contact_info": {"helpline": "1800-11-1979", "website": "https://pmsvanidhi.mohua.gov.in"},
        "official_website": "https://pmsvanidhi.mohua.gov.in",
        "apply_link": "https://pmsvanidhi.mohua.gov.in",
        "has_application_fee": False,
        "icon": "🛒",
        "color": "orange",
        "is_featured": False,
        "priority": 70,
        "tags": ["street vendor", "loan", "विक्रेता"],
        "search_keywords": ["svanidhi", "street vendor", "loan"],
    },

    {
        "scheme_id": "pmkvy",
        "scheme_name": "PM Kaushal Vikas Yojana",
        "scheme_name_hindi": "प्रधानमंत्री कौशल विकास योजना",
        "short_description": "Free skill development training for youth",
        "short_description_hindi": "युवाओं के लिए मुफ्त कौशल विकास प्रशिक्षण",
        "level": "central",
        "state": None,
        "category": "skill_development",
        "full_description": "PMKVY provides free short-duration skill training and certification to youth for employability.",
        "full_description_hindi": "PMKVY रोजगार के लिए युवाओं को मुफ्त अल्पकालिक कौशल प्रशिक्षण और प्रमाणन प्रदान करती है।",
        "benefits": [
            {"title": "Free Training", "description": "Short-term skill training courses", "type": "training"},
            {"title": "Certification", "description": "Government recognized certificates", "type": "service"},
            {"title": "Placement Assistance", "description": "Job placement support", "type": "service"},
        ],
        "eligibility": {
            "age_min": 15, "age_max": 45, "gender": None,
            "income_limit": None, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": None, "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• आयु 15-45 वर्ष\n• आधार कार्ड आवश्यक",
        "target_beneficiaries": ["Youth", "School/College dropouts", "Unemployed"],
        "target_beneficiaries_hindi": ["युवा", "स्कूल/कॉलेज ड्रॉपआउट", "बेरोजगार"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Education Certificate", "name_hindi": "शिक्षा प्रमाण पत्र", "required": False},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Portal", "title_hindi": "पोर्टल पर जाएं", "description": "Go to pmkvyofficial.org", "description_hindi": "pmkvyofficial.org पर जाएं"},
            {"step_number": 2, "title": "Find Training Center", "title_hindi": "प्रशिक्षण केंद्र खोजें", "description": "Locate nearest training center", "description_hindi": "निकटतम प्रशिक्षण केंद्र खोजें"},
        ],
        "application_mode": "both",
        "contact_info": {"helpline": "088000-55555", "email": "support@pmkvyofficial.org", "website": "https://www.pmkvyofficial.org"},
        "official_website": "https://www.pmkvyofficial.org",
        "apply_link": "https://www.pmkvyofficial.org",
        "has_application_fee": False,
        "icon": "🎓",
        "color": "indigo",
        "is_featured": True,
        "priority": 85,
        "tags": ["skill", "training", "कौशल"],
        "search_keywords": ["kaushal", "skill", "training"],
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
        "full_description": "Mukhyamantri Ladli Behna Yojana is a scheme by the Madhya Pradesh government to provide financial assistance of ₹1,250 per month to women aged 21-60 years. The scheme aims to empower women and improve their economic status.",
        "full_description_hindi": "मुख्यमंत्री लाड़ली बहना योजना मध्य प्रदेश सरकार की एक योजना है जो 21-60 वर्ष की आयु की महिलाओं को ₹1,250 प्रति माह की वित्तीय सहायता प्रदान करती है। यह योजना महिलाओं को सशक्त बनाने और उनकी आर्थिक स्थिति में सुधार करने का लक्ष्य रखती है।",
        "benefits": [
            {"title": "Monthly Assistance", "description": "₹1,250 per month directly to bank account", "amount": "₹1,250/month", "type": "financial"},
            {"title": "Direct Benefit Transfer", "description": "Amount credited directly to bank account", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 21, "age_max": 60, "gender": "female",
            "income_limit": 250000, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": "Madhya Pradesh", "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• मध्य प्रदेश की मूल निवासी महिला\n• आयु 21-60 वर्ष\n• परिवार की वार्षिक आय ₹2.5 लाख से कम\n• आधार कार्ड और बैंक खाता आवश्यक\n• परिवार में कोई आयकर दाता न हो",
        "target_beneficiaries": ["Women aged 21-60", "Madhya Pradesh residents"],
        "target_beneficiaries_hindi": ["21-60 वर्ष की महिलाएं", "मध्य प्रदेश निवासी"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Domicile Certificate", "name_hindi": "मूल निवास प्रमाण पत्र"},
            {"name": "Income Certificate", "name_hindi": "आय प्रमाण पत्र"},
            {"name": "Bank Passbook", "name_hindi": "बैंक पासबुक"},
            {"name": "Samagra ID", "name_hindi": "समग्र आईडी"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Camp or Portal", "title_hindi": "कैंप या पोर्टल पर जाएं", "description": "Visit designated camps or cmladlibahna.mp.gov.in", "description_hindi": "निर्धारित कैंपों या cmladlibahna.mp.gov.in पर जाएं"},
            {"step_number": 2, "title": "Fill Application Form", "title_hindi": "आवेदन पत्र भरें", "description": "Fill the application form with required details", "description_hindi": "आवश्यक विवरण के साथ आवेदन पत्र भरें"},
            {"step_number": 3, "title": "Submit with Documents", "title_hindi": "दस्तावेजों के साथ जमा करें", "description": "Submit form with all required documents", "description_hindi": "सभी आवश्यक दस्तावेजों के साथ फॉर्म जमा करें"},
        ],
        "application_mode": "online",
        "contact_info": {"helpline": "0755-2555999", "website": "https://cmladlibahna.mp.gov.in"},
        "official_website": "https://cmladlibahna.mp.gov.in",
        "has_application_fee": False,
        "icon": "👩",
        "color": "pink",
        "is_featured": True,
        "priority": 100,
        "tags": ["women", "mp", "महिला", "मध्य प्रदेश"],
        "search_keywords": ["ladli behna", "mp", "women", "ladli"],
    },
    
    {
        "scheme_id": "mh_ladki_bahin",
        "scheme_name": "Mukhyamantri Majhi Ladki Bahin Yojana",
        "scheme_name_hindi": "मुख्यमंत्री माझी लाडकी बहीण योजना",
        "short_description": "Financial assistance of ₹1,500/month to women",
        "short_description_hindi": "महिलाओं को ₹1,500/माह की वित्तीय सहायता",
        "level": "state",
        "state": "Maharashtra",
        "category": "women_child",
        "full_description": "Mukhyamantri Majhi Ladki Bahin Yojana is a scheme by the Maharashtra government to provide financial assistance of ₹1,500 per month to eligible women aged 21-65 years.",
        "full_description_hindi": "मुख्यमंत्री माझी लाडकी बहीण योजना महाराष्ट्र सरकार की एक योजना है जो 21-65 वर्ष की पात्र महिलाओं को ₹1,500 प्रति माह की वित्तीय सहायता प्रदान करती है।",
        "benefits": [
            {"title": "Monthly Assistance", "description": "₹1,500 per month directly to bank account", "amount": "₹1,500/month", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 21, "age_max": 65, "gender": "female",
            "income_limit": 250000, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": "Maharashtra", "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• महाराष्ट्र की मूल निवासी महिला\n• आयु 21-65 वर्ष\n• परिवार की वार्षिक आय ₹2.5 लाख से कम\n• आधार कार्ड और बैंक खाता आवश्यक",
        "target_beneficiaries": ["Women aged 21-65", "Maharashtra residents"],
        "target_beneficiaries_hindi": ["21-65 वर्ष की महिलाएं", "महाराष्ट्र निवासी"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Domicile Certificate", "name_hindi": "मूल निवास प्रमाण पत्र"},
            {"name": "Income Certificate", "name_hindi": "आय प्रमाण पत्र"},
            {"name": "Bank Passbook", "name_hindi": "बैंक पासबुक"},
            {"name": "Ration Card", "name_hindi": "राशन कार्ड"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Official Portal", "title_hindi": "आधिकारिक पोर्टल पर जाएं", "description": "Go to ladakibahin.maharashtra.gov.in", "description_hindi": "ladakibahin.maharashtra.gov.in पर जाएं"},
            {"step_number": 2, "title": "Fill Application", "title_hindi": "आवेदन भरें", "description": "Complete the online application form", "description_hindi": "ऑनलाइन आवेदन पत्र पूरा करें"},
            {"step_number": 3, "title": "Submit Documents", "title_hindi": "दस्तावेज जमा करें", "description": "Upload required documents and submit", "description_hindi": "आवश्यक दस्तावेज अपलोड करें और जमा करें"},
        ],
        "application_mode": "online",
        "contact_info": {"helpline": "181", "website": "https://ladakibahin.maharashtra.gov.in"},
        "official_website": "https://ladakibahin.maharashtra.gov.in",
        "has_application_fee": False,
        "icon": "👩",
        "color": "pink",
        "is_featured": True,
        "priority": 100,
        "tags": ["women", "maharashtra", "महिला", "महाराष्ट्र"],
        "search_keywords": ["ladki bahin", "women", "maharashtra"],
    },
    
    {
        "scheme_id": "up_kanya_sumangala",
        "scheme_name": "Mukhyamantri Kanya Sumangala Yojana",
        "scheme_name_hindi": "मुख्यमंत्री कन्या सुमंगला योजना",
        "short_description": "Financial assistance up to ₹25,000 for girl child",
        "short_description_hindi": "बालिका के लिए ₹25,000 तक की वित्तीय सहायता",
        "level": "state",
        "state": "Uttar Pradesh",
        "category": "women_child",
        "full_description": "Mukhyamantri Kanya Sumangala Yojana is a scheme by the Uttar Pradesh government to provide financial assistance to girl children from birth to graduation. The scheme provides ₹25,000 in 6 stages.",
        "full_description_hindi": "मुख्यमंत्री कन्या सुमंगला योजना उत्तर प्रदेश सरकार की एक योजना है जो जन्म से स्नातक तक बालिकाओं को वित्तीय सहायता प्रदान करती है। यह योजना 6 चरणों में ₹25,000 प्रदान करती है।",
        "benefits": [
            {"title": "Total Assistance", "description": "₹25,000 in 6 stages", "amount": "₹25,000", "type": "financial"},
            {"title": "Stage-wise Benefits", "description": "₹5,000 at birth, ₹2,000 at each stage", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 0, "age_max": 22, "gender": "female",
            "income_limit": 300000, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": "Uttar Pradesh", "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• उत्तर प्रदेश की मूल निवासी बालिका\n• परिवार की वार्षिक आय ₹3 लाख से कम\n• अधिकतम 2 बालिकाओं के लिए लाभ\n• जन्म से स्नातक तक",
        "target_beneficiaries": ["Girl children", "UP residents"],
        "target_beneficiaries_hindi": ["बालिकाएं", "उत्तर प्रदेश निवासी"],
        "required_documents": [
            {"name": "Birth Certificate", "name_hindi": "जन्म प्रमाण पत्र"},
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Income Certificate", "name_hindi": "आय प्रमाण पत्र"},
            {"name": "Domicile Certificate", "name_hindi": "मूल निवास प्रमाण पत्र"},
            {"name": "Bank Passbook", "name_hindi": "बैंक पासबुक"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Official Portal", "title_hindi": "आधिकारिक पोर्टल पर जाएं", "description": "Go to mksy.up.gov.in", "description_hindi": "mksy.up.gov.in पर जाएं"},
            {"step_number": 2, "title": "Fill Application", "title_hindi": "आवेदन भरें", "description": "Complete the online application form", "description_hindi": "ऑनलाइन आवेदन पत्र पूरा करें"},
            {"step_number": 3, "title": "Submit Documents", "title_hindi": "दस्तावेज जमा करें", "description": "Upload required documents and submit", "description_hindi": "आवश्यक दस्तावेज अपलोड करें और जमा करें"},
        ],
        "application_mode": "online",
        "contact_info": {"helpline": "1800-180-5333", "website": "https://mksy.up.gov.in"},
        "official_website": "https://mksy.up.gov.in",
        "has_application_fee": False,
        "icon": "👧",
        "color": "pink",
        "is_featured": True,
        "priority": 95,
        "tags": ["girl child", "up", "बालिका", "उत्तर प्रदेश"],
        "search_keywords": ["kanya sumangala", "girl child", "up"],
    },
    
    {
        "scheme_id": "rj_chiranjeevi",
        "scheme_name": "Mukhyamantri Chiranjeevi Yojana",
        "scheme_name_hindi": "मुख्यमंत्री चिरंजीवी योजना",
        "short_description": "Health insurance cover of ₹25 lakh per family",
        "short_description_hindi": "प्रति परिवार ₹25 लाख का स्वास्थ्य बीमा",
        "level": "state",
        "state": "Rajasthan",
        "category": "health",
        "full_description": "Mukhyamantri Chiranjeevi Yojana is a scheme by the Rajasthan government to provide health insurance cover of ₹25 lakh per family per year to all residents of Rajasthan.",
        "full_description_hindi": "मुख्यमंत्री चिरंजीवी योजना राजस्थान सरकार की एक योजना है जो राजस्थान के सभी निवासियों को प्रति परिवार प्रति वर्ष ₹25 लाख का स्वास्थ्य बीमा कवर प्रदान करती है।",
        "benefits": [
            {"title": "Health Cover", "description": "₹25 lakh per family per year", "amount": "₹25,00,000", "type": "financial"},
            {"title": "Cashless Treatment", "description": "At government and empanelled private hospitals", "type": "service"},
        ],
        "eligibility": {
            "age_min": None, "age_max": None, "gender": None,
            "income_limit": None, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": "Rajasthan", "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• राजस्थान का मूल निवासी\n• आयु की कोई सीमा नहीं\n• जन आधार कार्ड आवश्यक\n• परिवार के सभी सदस्य पात्र",
        "target_beneficiaries": ["Rajasthan residents", "All age groups"],
        "target_beneficiaries_hindi": ["राजस्थान निवासी", "सभी आयु वर्ग"],
        "required_documents": [
            {"name": "Jan Aadhaar Card", "name_hindi": "जन आधार कार्ड"},
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Domicile Certificate", "name_hindi": "मूल निवास प्रमाण पत्र"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Official Portal", "title_hindi": "आधिकारिक पोर्टल पर जाएं", "description": "Go to health.rajasthan.gov.in", "description_hindi": "health.rajasthan.gov.in पर जाएं"},
            {"step_number": 2, "title": "Register with Jan Aadhaar", "title_hindi": "जन आधार से पंजीकरण करें", "description": "Register using your Jan Aadhaar number", "description_hindi": "अपने जन आधार नंबर का उपयोग करके पंजीकरण करें"},
            {"step_number": 3, "title": "Get Insurance Card", "title_hindi": "बीमा कार्ड प्राप्त करें", "description": "Download your Chiranjeevi card", "description_hindi": "अपना चिरंजीवी कार्ड डाउनलोड करें"},
        ],
        "application_mode": "online",
        "contact_info": {"helpline": "1800-180-6127", "website": "https://health.rajasthan.gov.in"},
        "official_website": "https://health.rajasthan.gov.in",
        "has_application_fee": False,
        "icon": "🏥",
        "color": "teal",
        "is_featured": True,
        "priority": 95,
        "tags": ["health", "rajasthan", "स्वास्थ्य", "राजस्थान"],
        "search_keywords": ["chiranjeevi", "health", "rajasthan"],
    },
    
    {
        "scheme_id": "tn_kalaignar_magalir",
        "scheme_name": "Kalaignar Magalir Urimai Thogai",
        "scheme_name_hindi": "कलैग्नार मगलिर उरिमै थोगै",
        "short_description": "Monthly assistance of ₹1,000 to women heads of families",
        "short_description_hindi": "परिवार की महिला मुखियाओं को ₹1,000/माह की सहायता",
        "level": "state",
        "state": "Tamil Nadu",
        "category": "women_child",
        "full_description": "Kalaignar Magalir Urimai Thogai is a scheme by the Tamil Nadu government to provide ₹1,000 per month to eligible women heads of families in Tamil Nadu.",
        "full_description_hindi": "कलैग्नार मगलिर उरिमै थोगै तमिलनाडु सरकार की एक योजना है जो तमिलनाडु में पात्र महिला परिवार मुखियाओं को ₹1,000 प्रति माह प्रदान करती है।",
        "benefits": [
            {"title": "Monthly Assistance", "description": "₹1,000 per month", "amount": "₹1,000/month", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 21, "age_max": None, "gender": "female",
            "income_limit": 250000, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": "Tamil Nadu", "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• तमिलनाडु की मूल निवासी महिला\n• आयु 21 वर्ष से अधिक\n• परिवार की वार्षिक आय ₹2.5 लाख से कम\n• परिवार की मुखिया महिला हो",
        "target_beneficiaries": ["Women heads of families", "Tamil Nadu residents"],
        "target_beneficiaries_hindi": ["परिवार की महिला मुखिया", "तमिलनाडु निवासी"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Ration Card", "name_hindi": "राशन कार्ड"},
            {"name": "Income Certificate", "name_hindi": "आय प्रमाण पत्र"},
            {"name": "Bank Passbook", "name_hindi": "बैंक पासबुक"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit e-Sevai Center", "title_hindi": "ई-सेवा केंद्र पर जाएं", "description": "Visit nearest e-Sevai center or apply online", "description_hindi": "निकटतम ई-सेवा केंद्र पर जाएं या ऑनलाइन आवेदन करें"},
            {"step_number": 2, "title": "Fill Application", "title_hindi": "आवेदन भरें", "description": "Complete the application form", "description_hindi": "आवेदन पत्र पूरा करें"},
            {"step_number": 3, "title": "Submit Documents", "title_hindi": "दस्तावेज जमा करें", "description": "Submit required documents", "description_hindi": "आवश्यक दस्तावेज जमा करें"},
        ],
        "application_mode": "both",
        "contact_info": {"helpline": "1100", "website": "https://kmut.tn.gov.in"},
        "official_website": "https://kmut.tn.gov.in",
        "has_application_fee": False,
        "icon": "👩",
        "color": "pink",
        "is_featured": True,
        "priority": 95,
        "tags": ["women", "tamil nadu", "महिला", "तमिलनाडु"],
        "search_keywords": ["kalaignar", "women", "tamil nadu"],
    },
    
    {
        "scheme_id": "ka_gruha_lakshmi",
        "scheme_name": "Gruha Lakshmi Yojana",
        "scheme_name_hindi": "गृह लक्ष्मी योजना",
        "short_description": "Monthly assistance of ₹2,000 to women heads of families",
        "short_description_hindi": "परिवार की महिला मुखियाओं को ₹2,000/माह की सहायता",
        "level": "state",
        "state": "Karnataka",
        "category": "women_child",
        "full_description": "Gruha Lakshmi Yojana is a scheme by the Karnataka government to provide ₹2,000 per month to women heads of families in Karnataka.",
        "full_description_hindi": "गृह लक्ष्मी योजना कर्नाटक सरकार की एक योजना है जो कर्नाटक में महिला परिवार मुखियाओं को ₹2,000 प्रति माह प्रदान करती है।",
        "benefits": [
            {"title": "Monthly Assistance", "description": "₹2,000 per month", "amount": "₹2,000/month", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 18, "age_max": None, "gender": "female",
            "income_limit": None, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": "Karnataka", "disability_required": False,
            "bpl_required": False, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• कर्नाटक की मूल निवासी महिला\n• परिवार की मुखिया महिला\n• BPL/APL परिवार\n• आधार कार्ड और बैंक खाता आवश्यक",
        "target_beneficiaries": ["Women heads of families", "Karnataka residents"],
        "target_beneficiaries_hindi": ["परिवार की महिला मुखिया", "कर्नाटक निवासी"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "Ration Card", "name_hindi": "राशन कार्ड"},
            {"name": "Bank Passbook", "name_hindi": "बैंक पासबुक"},
            {"name": "Address Proof", "name_hindi": "पता प्रमाण"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Official Portal", "title_hindi": "आधिकारिक पोर्टल पर जाएं", "description": "Go to sevasindhuservices.karnataka.gov.in", "description_hindi": "sevasindhuservices.karnataka.gov.in पर जाएं"},
            {"step_number": 2, "title": "Fill Application", "title_hindi": "आवेदन भरें", "description": "Complete the online application form", "description_hindi": "ऑनलाइन आवेदन पत्र पूरा करें"},
            {"step_number": 3, "title": "Submit Documents", "title_hindi": "दस्तावेज जमा करें", "description": "Upload required documents", "description_hindi": "आवश्यक दस्तावेज अपलोड करें"},
        ],
        "application_mode": "online",
        "contact_info": {"helpline": "1902", "website": "https://sevasindhuservices.karnataka.gov.in"},
        "official_website": "https://sevasindhuservices.karnataka.gov.in",
        "has_application_fee": False,
        "icon": "👩",
        "color": "pink",
        "is_featured": True,
        "priority": 95,
        "tags": ["women", "karnataka", "महिला", "कर्नाटक"],
        "search_keywords": ["gruha lakshmi", "women", "karnataka"],
    },
    
    {
        "scheme_id": "br_kanya_vivah",
        "scheme_name": "Mukhyamantri Kanya Vivah Yojana",
        "scheme_name_hindi": "मुख्यमंत्री कन्या विवाह योजना",
        "short_description": "Financial assistance of ₹5,000 for daughter's marriage",
        "short_description_hindi": "बेटी के विवाह के लिए ₹5,000 की वित्तीय सहायता",
        "level": "state",
        "state": "Bihar",
        "category": "women_child",
        "full_description": "Mukhyamantri Kanya Vivah Yojana is a scheme by the Bihar government to provide financial assistance of ₹5,000 to families below poverty line for their daughter's marriage.",
        "full_description_hindi": "मुख्यमंत्री कन्या विवाह योजना बिहार सरकार की एक योजना है जो गरीबी रेखा से नीचे के परिवारों को उनकी बेटी के विवाह के लिए ₹5,000 की वित्तीय सहायता प्रदान करती है।",
        "benefits": [
            {"title": "Marriage Assistance", "description": "₹5,000 for daughter's marriage", "amount": "₹5,000", "type": "financial"},
        ],
        "eligibility": {
            "age_min": 18, "age_max": None, "gender": "female",
            "income_limit": 60000, "category": None,
            "education_level": None, "occupation": None,
            "domicile_state": "Bihar", "disability_required": False,
            "bpl_required": True, "aadhaar_required": True,
        },
        "eligibility_details_hindi": "• बिहार की मूल निवासी\n• BPL परिवार\n• कन्या की आयु 18 वर्ष से अधिक\n• अधिकतम 2 बेटियों के लिए लाभ",
        "target_beneficiaries": ["BPL families", "Bihar residents"],
        "target_beneficiaries_hindi": ["BPL परिवार", "बिहार निवासी"],
        "required_documents": [
            {"name": "Aadhaar Card", "name_hindi": "आधार कार्ड"},
            {"name": "BPL Card", "name_hindi": "BPL कार्ड"},
            {"name": "Age Proof", "name_hindi": "आयु प्रमाण"},
            {"name": "Bank Passbook", "name_hindi": "बैंक पासबुक"},
        ],
        "application_steps": [
            {"step_number": 1, "title": "Visit Block Office", "title_hindi": "प्रखंड कार्यालय पर जाएं", "description": "Visit nearest block office or apply online", "description_hindi": "निकटतम प्रखंड कार्यालय पर जाएं या ऑनलाइन आवेदन करें"},
            {"step_number": 2, "title": "Fill Application", "title_hindi": "आवेदन भरें", "description": "Fill the application form", "description_hindi": "आवेदन पत्र भरें"},
            {"step_number": 3, "title": "Submit Documents", "title_hindi": "दस्तावेज जमा करें", "description": "Submit required documents", "description_hindi": "आवश्यक दस्तावेज जमा करें"},
        ],
        "application_mode": "both",
        "contact_info": {"helpline": "1800-345-6222", "website": "https://state.bihar.gov.in"},
        "official_website": "https://state.bihar.gov.in",
        "has_application_fee": False,
        "icon": "💒",
        "color": "pink",
        "is_featured": False,
        "priority": 80,
        "tags": ["marriage", "bihar", "विवाह", "बिहार"],
        "search_keywords": ["kanya vivah", "marriage", "bihar"],
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
    
    ayushman = await schemes_col.find_one({"scheme_id": "ayushman_bharat"})
    if ayushman:
        logger.info(f"✅ Verified: ayushman_bharat exists (name={ayushman.get('scheme_name')})")
    else:
        logger.error("❌ VERIFY FAILED: ayushman_bharat NOT FOUND!")

    return {"inserted": inserted, "updated": updated, "total": total}


if __name__ == "__main__":
    asyncio.run(seed())
