// lib/core/master_date/schemes_data.dart
// ============================================================
// GOVERNMENT SCHEMES MASTER DATA
// ============================================================
// All schemes are defined here as static data.
// To add/update/delete a scheme, modify this file.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;

// ============================================================
// SCHEME MODEL
// ============================================================

class GovernmentScheme {
  final String schemeId;
  final String schemeName;
  final String schemeNameHindi;
  final String shortDescription;
  final String shortDescriptionHindi;
  final String level; // central or state
  final String? state;
  final String category;
  final String fullDescription;
  final String fullDescriptionHindi;
  final List<SchemeBenefit> benefits;
  final SchemeEligibility eligibility;
  final String eligibilityDetailsHindi;
  final List<String> targetBeneficiaries;
  final List<String> targetBeneficiariesHindi;
  final List<SchemeDocument> requiredDocuments;
  final List<SchemeApplicationStep> applicationSteps;
  final String applicationMode;
  final SchemeContactInfo contactInfo;
  final String? officialWebsite;
  final String? applyLink;
  final bool hasApplicationFee;
  final int applicationFee;
  final String? feeDetailsHindi;
  final String icon;
  final String color;
  final bool isFeatured;
  final List<String> tags;

  const GovernmentScheme({
    required this.schemeId,
    required this.schemeName,
    required this.schemeNameHindi,
    required this.shortDescription,
    required this.shortDescriptionHindi,
    this.level = 'central',
    this.state,
    required this.category,
    required this.fullDescription,
    required this.fullDescriptionHindi,
    this.benefits = const [],
    this.eligibility = const SchemeEligibility(),
    this.eligibilityDetailsHindi = '',
    this.targetBeneficiaries = const [],
    this.targetBeneficiariesHindi = const [],
    this.requiredDocuments = const [],
    this.applicationSteps = const [],
    this.applicationMode = 'online',
    this.contactInfo = const SchemeContactInfo(),
    this.officialWebsite,
    this.applyLink,
    this.hasApplicationFee = false,
    this.applicationFee = 0,
    this.feeDetailsHindi,
    this.icon = '📋',
    this.color = 'blue',
    this.isFeatured = false,
    this.tags = const [],
  });
}

class SchemeBenefit {
  final String title;
  final String description;
  final String? amount;
  final String type;

  const SchemeBenefit({
    required this.title,
    required this.description,
    this.amount,
    this.type = 'financial',
  });
}

class SchemeEligibility {
  final int? ageMin;
  final int? ageMax;
  final String? gender;
  final int? incomeLimit;
  final List<String>? category;
  final String? educationLevel;
  final String? occupation;
  final String? domicileState;
  final bool disabilityRequired;
  final bool bplRequired;
  final bool aadhaarRequired;

  const SchemeEligibility({
    this.ageMin,
    this.ageMax,
    this.gender,
    this.incomeLimit,
    this.category,
    this.educationLevel,
    this.occupation,
    this.domicileState,
    this.disabilityRequired = false,
    this.bplRequired = false,
    this.aadhaarRequired = true,
  });
}

class SchemeDocument {
  final String name;
  final String nameHindi;
  final bool required;
  final String? description;

  const SchemeDocument({
    required this.name,
    required this.nameHindi,
    this.required = true,
    this.description,
  });
}

class SchemeApplicationStep {
  final int stepNumber;
  final String title;
  final String titleHindi;
  final String description;
  final String descriptionHindi;

  const SchemeApplicationStep({
    required this.stepNumber,
    required this.title,
    required this.titleHindi,
    required this.description,
    required this.descriptionHindi,
  });
}

class SchemeContactInfo {
  final String? helpline;
  final String? email;
  final String? website;
  final String? officeAddress;

  const SchemeContactInfo({
    this.helpline,
    this.email,
    this.website,
    this.officeAddress,
  });
}

// ============================================================
// MASTER DATA
// ============================================================

class SchemesMasterData {
  // ============================================================
  // CENTRAL GOVERNMENT SCHEMES
  // ============================================================
  
  static const List<GovernmentScheme> centralSchemes = [
    // ----------------------------------------------------------
    // PM-KISAN (Pradhan Mantri Kisan Samman Nidhi)
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'pm_kisan',
      schemeName: 'PM-KISAN',
      schemeNameHindi: 'प्रधानमंत्री किसान सम्मान निधि',
      shortDescription: 'Financial assistance of ₹6,000/year to small farmers',
      shortDescriptionHindi: 'छोटे किसानों को ₹6,000/वर्ष की वित्तीय सहायता',
      level: 'central',
      category: 'agriculture',
      fullDescription: 'Pradhan Mantri Kisan Samman Nidhi (PM-KISAN) is a Central Sector Scheme providing income support to all landholding farmers\' families in the country. Under the scheme, an amount of ₹6000 per year is released in three equal installments of ₹2000 each to eligible farmer families.',
      fullDescriptionHindi: 'प्रधानमंत्री किसान सम्मान निधि (PM-KISAN) एक केंद्रीय क्षेत्र की योजना है जो देश के सभी भूमिधारक किसान परिवारों को आय सहायता प्रदान करती है। इस योजना के तहत, पात्र किसान परिवारों को ₹2000 की तीन समान किस्तों में प्रति वर्ष ₹6000 की राशि जारी की जाती है।',
      benefits: [
        SchemeBenefit(
          title: 'Direct Income Support',
          description: '₹6,000 per year in 3 installments',
          amount: '₹6,000/year',
          type: 'financial',
        ),
        SchemeBenefit(
          title: 'Direct Benefit Transfer',
          description: 'Amount credited directly to bank account',
          type: 'financial',
        ),
      ],
      eligibility: SchemeEligibility(
        ageMin: 18,
        incomeLimit: 300000,
        occupation: 'Farmer',
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• किसान परिवार के पास खेती योग्य भूमि होनी चाहिए\n• आयु 18 वर्ष या अधिक होनी चाहिए\n• आधार कार्ड आवश्यक है\n• बैंक खाता आवश्यक है',
      targetBeneficiaries: ['Small and marginal farmers', 'Landholding farmer families'],
      targetBeneficiariesHindi: ['छोटे और सीमांत किसान', 'भूमिधारक किसान परिवार'],
      requiredDocuments: [
        SchemeDocument(name: 'Aadhaar Card', nameHindi: 'आधार कार्ड'),
        SchemeDocument(name: 'Land Records', nameHindi: 'भूमि रिकॉर्ड'),
        SchemeDocument(name: 'Bank Passbook', nameHindi: 'बैंक पासबुक'),
        SchemeDocument(name: 'Mobile Number', nameHindi: 'मोबाइल नंबर'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Visit PM-KISAN Portal',
          titleHindi: 'PM-KISAN पोर्टल पर जाएं',
          description: 'Go to pmkisan.gov.in and click on "New Farmer Registration"',
          descriptionHindi: 'pmkisan.gov.in पर जाएं और "नया किसान पंजीकरण" पर क्लिक करें',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Fill Application Form',
          titleHindi: 'आवेदन पत्र भरें',
          description: 'Enter your Aadhaar number, mobile number and other details',
          descriptionHindi: 'अपना आधार नंबर, मोबाइल नंबर और अन्य विवरण दर्ज करें',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Upload Documents',
          titleHindi: 'दस्तावेज अपलोड करें',
          description: 'Upload scanned copies of required documents',
          descriptionHindi: 'आवश्यक दस्तावेजों की स्कैन की गई प्रतियां अपलोड करें',
        ),
        SchemeApplicationStep(
          stepNumber: 4,
          title: 'Submit Application',
          titleHindi: 'आवेदन जमा करें',
          description: 'Review and submit your application',
          descriptionHindi: 'अपने आवेदन की समीक्षा करें और जमा करें',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '155261 / 011-24300606',
        email: 'pmkisan-ict@gov.in',
        website: 'https://pmkisan.gov.in',
      ),
      officialWebsite: 'https://pmkisan.gov.in',
      applyLink: 'https://pmkisan.gov.in/RegistrationFormUpdated.aspx',
      hasApplicationFee: false,
      icon: '🌾',
      color: 'green',
      isFeatured: true,
      tags: ['farmer', 'agriculture', 'income support', 'किसान'],
    ),
    
    // ----------------------------------------------------------
    // AYUSHMAN BHARAT
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'ayushman_bharat',
      schemeName: 'Ayushman Bharat (PM-JAY)',
      schemeNameHindi: 'आयुष्मान भारत (PM-JAY)',
      shortDescription: 'Health insurance cover of ₹5 lakh per family per year',
      shortDescriptionHindi: 'प्रति परिवार प्रति वर्ष ₹5 लाख का स्वास्थ्य बीमा',
      level: 'central',
      category: 'health',
      fullDescription: 'Ayushman Bharat Pradhan Mantri Jan Arogya Yojana (PM-JAY) is the largest health assurance scheme in the world which aims at providing a health cover of ₹5 lakhs per family per year for secondary and tertiary care hospitalization.',
      fullDescriptionHindi: 'आयुष्मान भारत प्रधानमंत्री जन आरोग्य योजना (PM-JAY) दुनिया की सबसे बड़ी स्वास्थ्य बीमा योजना है जिसका उद्देश्य माध्यमिक और तृतीयक देखभाल अस्पताल में भर्ती के लिए प्रति परिवार प्रति वर्ष ₹5 लाख का स्वास्थ्य कवर प्रदान करना है।',
      benefits: [
        SchemeBenefit(
          title: 'Health Coverage',
          description: '₹5 lakh per family per year',
          amount: '₹5,00,000',
          type: 'financial',
        ),
        SchemeBenefit(
          title: 'Cashless Treatment',
          description: 'Cashless treatment at empanelled hospitals',
          type: 'service',
        ),
        SchemeBenefit(
          title: 'Pre-existing Diseases',
          description: 'Covered from day one',
          type: 'service',
        ),
      ],
      eligibility: SchemeEligibility(
        incomeLimit: 100000,
        bplRequired: true,
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• SECC 2011 डेटा में शामिल परिवार\n• ग्रामीण क्षेत्रों में BPL परिवार\n• शहरी क्षेत्रों में श्रमिक परिवार\n• आयु या लिंग की कोई सीमा नहीं',
      targetBeneficiaries: ['BPL families', 'Low income households', 'Vulnerable communities'],
      targetBeneficiariesHindi: ['BPL परिवार', 'कम आय वाले परिवार', 'कमजोर समुदाय'],
      requiredDocuments: [
        SchemeDocument(name: 'Aadhaar Card', nameHindi: 'आधार कार्ड'),
        SchemeDocument(name: 'Ration Card', nameHindi: 'राशन कार्ड'),
        SchemeDocument(name: 'Income Certificate', nameHindi: 'आय प्रमाण पत्र'),
        SchemeDocument(name: 'SECC Data Verification', nameHindi: 'SECC डेटा सत्यापन'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Check Eligibility',
          titleHindi: 'पात्रता जांचें',
          description: 'Visit pmjay.gov.in and check if your family is eligible',
          descriptionHindi: 'pmjay.gov.in पर जाएं और जांचें कि आपका परिवार पात्र है या नहीं',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Get Ayushman Card',
          titleHindi: 'आयुष्मान कार्ड प्राप्त करें',
          description: 'Visit nearest CSC or empanelled hospital to get your card',
          descriptionHindi: 'अपना कार्ड प्राप्त करने के लिए निकटतम CSC या सूचीबद्ध अस्पताल पर जाएं',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Avail Benefits',
          titleHindi: 'लाभ प्राप्त करें',
          description: 'Show your card at empanelled hospitals for free treatment',
          descriptionHindi: 'मुफ्त इलाज के लिए सूचीबद्ध अस्पतालों में अपना कार्ड दिखाएं',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '14555 / 1800-111-565',
        email: 'pmjay@nha.gov.in',
        website: 'https://pmjay.gov.in',
      ),
      officialWebsite: 'https://pmjay.gov.in',
      applyLink: 'https://pmjay.gov.in/am-i-eligible',
      hasApplicationFee: false,
      icon: '🏥',
      color: 'teal',
      isFeatured: true,
      tags: ['health', 'insurance', 'hospital', 'स्वास्थ्य'],
    ),
    
    // ----------------------------------------------------------
    // PM AWAS YOJANA
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'pm_awas_yojana',
      schemeName: 'Pradhan Mantri Awas Yojana',
      schemeNameHindi: 'प्रधानमंत्री आवास योजना',
      shortDescription: 'Affordable housing for all by providing financial assistance',
      shortDescriptionHindi: 'वित्तीय सहायता प्रदान करके सभी के लिए किफायती आवास',
      level: 'central',
      category: 'housing',
      fullDescription: 'Pradhan Mantri Awas Yojana (PMAY) aims to provide affordable housing to the urban and rural poor. The scheme provides central assistance to eligible beneficiaries for construction of houses.',
      fullDescriptionHindi: 'प्रधानमंत्री आवास योजना (PMAY) का उद्देश्य शहरी और ग्रामीण गरीबों को किफायती आवास प्रदान करना है। यह योजना पात्र लाभार्थियों को घरों के निर्माण के लिए केंद्रीय सहायता प्रदान करती है।',
      benefits: [
        SchemeBenefit(
          title: 'Financial Assistance',
          description: 'Up to ₹2.67 lakh for house construction',
          amount: '₹2,67,000',
          type: 'financial',
        ),
        SchemeBenefit(
          title: 'Subsidized Loan',
          description: 'Interest subsidy on home loans',
          type: 'financial',
        ),
      ],
      eligibility: SchemeEligibility(
        incomeLimit: 1800000,
        bplRequired: false,
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• आवेदक के पास पक्का घर नहीं होना चाहिए\n• EWS: ₹3 लाख तक वार्षिक आय\n• LIG: ₹3-6 लाख वार्षिक आय\n• MIG: ₹6-18 लाख वार्षिक आय',
      targetBeneficiaries: ['EWS families', 'LIG families', 'MIG families', 'Slum dwellers'],
      targetBeneficiariesHindi: ['EWS परिवार', 'LIG परिवार', 'MIG परिवार', 'झुग्गी-झोपड़ी निवासी'],
      requiredDocuments: [
        SchemeDocument(name: 'Aadhaar Card', nameHindi: 'आधार कार्ड'),
        SchemeDocument(name: 'Income Certificate', nameHindi: 'आय प्रमाण पत्र'),
        SchemeDocument(name: 'Bank Account Details', nameHindi: 'बैंक खाता विवरण'),
        SchemeDocument(name: 'Affidavit (No Pucca House)', nameHindi: 'शपथ पत्र (पक्का घर नहीं)'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Visit Official Portal',
          titleHindi: 'आधिकारिक पोर्टल पर जाएं',
          description: 'Go to pmaymis.gov.in for urban or pmayg.nic.in for rural',
          descriptionHindi: 'शहरी के लिए pmaymis.gov.in या ग्रामीण के लिए pmayg.nic.in पर जाएं',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Select Citizen Assessment',
          titleHindi: 'नागरिक मूल्यांकन चुनें',
          description: 'Click on "Citizen Assessment" and fill the form',
          descriptionHindi: '"नागरिक मूल्यांकन" पर क्लिक करें और फॉर्म भरें',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Submit with Documents',
          titleHindi: 'दस्तावेजों के साथ जमा करें',
          description: 'Upload required documents and submit',
          descriptionHindi: 'आवश्यक दस्तावेज अपलोड करें और जमा करें',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '011-23060484',
        email: 'pmaymis@gov.in',
        website: 'https://pmaymis.gov.in',
      ),
      officialWebsite: 'https://pmaymis.gov.in',
      applyLink: 'https://pmaymis.gov.in/Open/Find_A_Beneficiary.aspx',
      hasApplicationFee: false,
      icon: '🏠',
      color: 'orange',
      isFeatured: true,
      tags: ['housing', 'awas', 'home loan', 'आवास'],
    ),
    
    // ----------------------------------------------------------
    // PM MUDRA YOJANA
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'pm_mudra',
      schemeName: 'Pradhan Mantri MUDRA Yojana',
      schemeNameHindi: 'प्रधानमंत्री मुद्रा योजना',
      shortDescription: 'Loans up to ₹10 lakh for small businesses',
      shortDescriptionHindi: 'छोटे व्यवसायों के लिए ₹10 लाख तक का ऋण',
      level: 'central',
      category: 'entrepreneurship',
      fullDescription: 'Pradhan Mantri MUDRA Yojana (PMMY) provides loans up to ₹10 lakh to non-corporate, non-farm small/micro enterprises. These loans are given by Commercial Banks, RRBs, Small Finance Banks, MFIs and NBFCs.',
      fullDescriptionHindi: 'प्रधानमंत्री मुद्रा योजना (PMMY) गैर-कॉर्पोरेट, गैर-कृषि लघु/सूक्ष्म उद्यमों को ₹10 लाख तक का ऋण प्रदान करती है। ये ऋण वाणिज्यिक बैंकों, RRBs, लघु वित्त बैंकों, MFIs और NBFCs द्वारा दिए जाते हैं।',
      benefits: [
        SchemeBenefit(
          title: 'Shishu Loan',
          description: 'Up to ₹50,000 for startups',
          amount: '₹50,000',
          type: 'financial',
        ),
        SchemeBenefit(
          title: 'Kishore Loan',
          description: '₹50,001 to ₹5 lakh for growing businesses',
          amount: '₹50,001 - ₹5,00,000',
          type: 'financial',
        ),
        SchemeBenefit(
          title: 'Tarun Loan',
          description: '₹5 lakh to ₹10 lakh for established businesses',
          amount: '₹5,00,001 - ₹10,00,000',
          type: 'financial',
        ),
      ],
      eligibility: SchemeEligibility(
        ageMin: 18,
        ageMax: 65,
        occupation: 'Entrepreneur/Small Business',
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• भारतीय नागरिक होना चाहिए\n• आयु 18-65 वर्ष के बीच\n• गैर-कृषि लघु/सूक्ष्म उद्यम\n• कोई डिफॉल्टर नहीं होना चाहिए',
      targetBeneficiaries: ['Small business owners', 'Micro entrepreneurs', 'Startup founders'],
      targetBeneficiariesHindi: ['छोटे व्यवसाय मालिक', 'सूक्ष्म उद्यमी', 'स्टार्टअप संस्थापक'],
      requiredDocuments: [
        SchemeDocument(name: 'Aadhaar Card', nameHindi: 'आधार कार्ड'),
        SchemeDocument(name: 'PAN Card', nameHindi: 'पैन कार्ड'),
        SchemeDocument(name: 'Business Plan', nameHindi: 'व्यवसाय योजना'),
        SchemeDocument(name: 'Bank Statement', nameHindi: 'बैंक विवरण'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Visit Bank/NBFC',
          titleHindi: 'बैंक/NBFC पर जाएं',
          description: 'Visit any bank branch or NBFC that offers MUDRA loans',
          descriptionHindi: 'किसी भी बैंक शाखा या NBFC पर जाएं जो मुद्रा ऋण प्रदान करता है',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Fill Application Form',
          titleHindi: 'आवेदन पत्र भरें',
          description: 'Fill the MUDRA loan application form with business details',
          descriptionHindi: 'व्यवसाय विवरण के साथ मुद्रा ऋण आवेदन पत्र भरें',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Submit Documents',
          titleHindi: 'दस्तावेज जमा करें',
          description: 'Submit all required documents including business plan',
          descriptionHindi: 'व्यवसाय योजना सहित सभी आवश्यक दस्तावेज जमा करें',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '1800-180-1111',
        email: 'mudra@sidbi.in',
        website: 'https://www.mudra.org.in',
      ),
      officialWebsite: 'https://www.mudra.org.in',
      applyLink: 'https://www.mudra.org.in/Offerings',
      hasApplicationFee: false,
      icon: '🚀',
      color: 'purple',
      isFeatured: true,
      tags: ['loan', 'business', 'entrepreneur', 'व्यवसाय'],
    ),
    
    // ----------------------------------------------------------
    // SUKANYA SAMRIDDHI YOJANA
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'sukanya_samriddhi',
      schemeName: 'Sukanya Samriddhi Yojana',
      schemeNameHindi: 'सुकन्या समृद्धि योजना',
      shortDescription: 'Small savings scheme for girl child education and marriage',
      shortDescriptionHindi: 'बालिका शिक्षा और विवाह के लिए लघु बचत योजना',
      level: 'central',
      category: 'women_child',
      fullDescription: 'Sukanya Samriddhi Yojana is a small deposit scheme for the girl child launched as a part of the Beti Bachao Beti Padhao campaign. The scheme encourages parents to build a fund for the future education and marriage expenses for their female child.',
      fullDescriptionHindi: 'सुकन्या समृद्धि योजना बेटी बचाओ बेटी पढ़ाओ अभियान के एक भाग के रूप में शुरू की गई बालिका के लिए एक लघु जमा योजना है। यह योजना माता-पिता को अपनी बालिका की भविष्य की शिक्षा और विवाह के खर्चों के लिए एक कोष बनाने के लिए प्रोत्साहित करती है।',
      benefits: [
        SchemeBenefit(
          title: 'High Interest Rate',
          description: 'Currently 8.2% per annum (highest among small savings)',
          amount: '8.2% p.a.',
          type: 'financial',
        ),
        SchemeBenefit(
          title: 'Tax Benefits',
          description: 'Tax deduction under Section 80C',
          type: 'financial',
        ),
        SchemeBenefit(
          title: 'Maturity',
          description: 'Account matures after 21 years or on marriage after 18',
          type: 'financial',
        ),
      ],
      eligibility: SchemeEligibility(
        ageMin: 0,
        ageMax: 10,
        gender: 'female',
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• बालिका की आयु 10 वर्ष से कम होनी चाहिए\n• अधिकतम 2 बालिकाओं के लिए खाता खोला जा सकता है\n• बालिका की ओर से माता-पिता या अभिभावक खाता खोल सकते हैं',
      targetBeneficiaries: ['Girl children below 10 years', 'Parents of girl children'],
      targetBeneficiariesHindi: ['10 वर्ष से कम आयु की बालिकाएं', 'बालिकाओं के माता-पिता'],
      requiredDocuments: [
        SchemeDocument(name: 'Birth Certificate of Girl Child', nameHindi: 'बालिका का जन्म प्रमाण पत्र'),
        SchemeDocument(name: 'Aadhaar Card of Parent/Guardian', nameHindi: 'माता-पिता/अभिभावक का आधार कार्ड'),
        SchemeDocument(name: 'Address Proof', nameHindi: 'पता प्रमाण'),
        SchemeDocument(name: 'Photograph', nameHindi: 'फोटो'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Visit Post Office/Bank',
          titleHindi: 'डाकघर/बैंक पर जाएं',
          description: 'Visit any authorized post office or bank branch',
          descriptionHindi: 'किसी भी अधिकृत डाकघर या बैंक शाखा पर जाएं',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Fill Account Opening Form',
          titleHindi: 'खाता खोलने का फॉर्म भरें',
          description: 'Fill the Sukanya Samriddhi account opening form',
          descriptionHindi: 'सुकन्या समृद्धि खाता खोलने का फॉर्म भरें',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Deposit Initial Amount',
          titleHindi: 'प्रारंभिक राशि जमा करें',
          description: 'Minimum ₹250 to open the account',
          descriptionHindi: 'खाता खोलने के लिए न्यूनतम ₹250',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '1800-11-1555',
        website: 'https://www.indiapost.gov.in',
      ),
      officialWebsite: 'https://www.indiapost.gov.in/Financial/Pages/Content/Post-Office-Saving-Schemes.aspx',
      hasApplicationFee: false,
      icon: '👧',
      color: 'pink',
      isFeatured: true,
      tags: ['girl child', 'savings', 'education', 'बालिका'],
    ),
    
    // ----------------------------------------------------------
    // PM JEEVAN JYOTI BIMA YOJANA
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'pmjjby',
      schemeName: 'PM Jeevan Jyoti Bima Yojana',
      schemeNameHindi: 'प्रधानमंत्री जीवन ज्योति बीमा योजना',
      shortDescription: 'Life insurance cover of ₹2 lakh at ₹436/year',
      shortDescriptionHindi: '₹436/वर्ष पर ₹2 लाख का जीवन बीमा कवर',
      level: 'central',
      category: 'insurance',
      fullDescription: 'Pradhan Mantri Jeevan Jyoti Bima Yojana (PMJJBY) is a government-backed life insurance scheme in India. It offers a renewable one-year life cover of ₹2 lakh to all savings bank account holders in the age group of 18 to 50 years.',
      fullDescriptionHindi: 'प्रधानमंत्री जीवन ज्योति बीमा योजना (PMJJBY) भारत में सरकार समर्थित जीवन बीमा योजना है। यह 18 से 50 वर्ष की आयु वर्ग के सभी बचत बैंक खाताधारकों को ₹2 लाख का एक वर्षीय नवीकरणीय जीवन कवर प्रदान करती है।',
      benefits: [
        SchemeBenefit(
          title: 'Life Cover',
          description: '₹2 lakh in case of death due to any reason',
          amount: '₹2,00,000',
          type: 'financial',
        ),
        SchemeBenefit(
          title: 'Low Premium',
          description: 'Only ₹436 per year',
          amount: '₹436/year',
          type: 'financial',
        ),
      ],
      eligibility: SchemeEligibility(
        ageMin: 18,
        ageMax: 50,
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• आयु 18-50 वर्ष\n• बचत बैंक खाता होना चाहिए\n• आधार कार्ड आवश्यक\n• बैंक खाते से ऑटो-डेबिट सुविधा',
      targetBeneficiaries: ['Bank account holders', 'Working professionals', 'Self-employed individuals'],
      targetBeneficiariesHindi: ['बैंक खाताधारक', 'कामकाजी पेशेवर', 'स्वरोजगार'],
      requiredDocuments: [
        SchemeDocument(name: 'Aadhaar Card', nameHindi: 'आधार कार्ड'),
        SchemeDocument(name: 'Bank Account', nameHindi: 'बैंक खाता'),
        SchemeDocument(name: 'Nominee Details', nameHindi: 'नामांकित व्यक्ति विवरण'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Visit Your Bank',
          titleHindi: 'अपने बैंक पर जाएं',
          description: 'Go to your bank branch and request PMJJBY enrollment',
          descriptionHindi: 'अपनी बैंक शाखा पर जाएं और PMJJBY नामांकन का अनुरोध करें',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Fill Enrollment Form',
          titleHindi: 'नामांकन फॉर्म भरें',
          description: 'Fill the PMJJBY enrollment form with nominee details',
          descriptionHindi: 'नामांकित व्यक्ति विवरण के साथ PMJJBY नामांकन फॉर्म भरें',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Auto-Debit Setup',
          titleHindi: 'ऑटो-डेबिट सेटअप',
          description: 'Enable auto-debit for annual premium',
          descriptionHindi: 'वार्षिक प्रीमियम के लिए ऑटो-डेबिट सक्षम करें',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '1800-180-1111',
        website: 'https://jansuraksha.gov.in',
      ),
      officialWebsite: 'https://jansuraksha.gov.in/PMJJBY.aspx',
      hasApplicationFee: true,
      applicationFee: 436,
      feeDetailsHindi: 'वार्षिक प्रीमियम: ₹436',
      icon: '🛡️',
      color: 'indigo',
      isFeatured: false,
      tags: ['insurance', 'life insurance', 'बीमा'],
    ),
  ];

  // ============================================================
  // STATE GOVERNMENT SCHEMES
  // ============================================================
  
  static const List<GovernmentScheme> stateSchemes = [
    // ----------------------------------------------------------
    // MADHYA PRADESH - Ladli Behna Yojana
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'mp_ladli_behna',
      schemeName: 'Mukhyamantri Ladli Behna Yojana',
      schemeNameHindi: 'मुख्यमंत्री लाड़ली बहना योजना',
      shortDescription: 'Financial assistance of ₹1,250/month to women',
      shortDescriptionHindi: 'महिलाओं को ₹1,250/माह की वित्तीय सहायता',
      level: 'state',
      state: 'Madhya Pradesh',
      category: 'women_child',
      fullDescription: 'Mukhyamantri Ladli Behna Yojana is a scheme by the Madhya Pradesh government to provide financial assistance of ₹1,250 per month to women aged 21-60 years. The scheme aims to empower women and improve their economic status.',
      fullDescriptionHindi: 'मुख्यमंत्री लाड़ली बहना योजना मध्य प्रदेश सरकार की एक योजना है जो 21-60 वर्ष की आयु की महिलाओं को ₹1,250 प्रति माह की वित्तीय सहायता प्रदान करती है। यह योजना महिलाओं को सशक्त बनाने और उनकी आर्थिक स्थिति में सुधार करने का लक्ष्य रखती है।',
      benefits: [
        SchemeBenefit(
          title: 'Monthly Assistance',
          description: '₹1,250 per month directly to bank account',
          amount: '₹1,250/month',
          type: 'financial',
        ),
        SchemeBenefit(
          title: 'Direct Benefit Transfer',
          description: 'Amount credited directly to bank account',
          type: 'financial',
        ),
      ],
      eligibility: SchemeEligibility(
        ageMin: 21,
        ageMax: 60,
        gender: 'female',
        incomeLimit: 250000,
        domicileState: 'Madhya Pradesh',
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• मध्य प्रदेश की मूल निवासी महिला\n• आयु 21-60 वर्ष\n• परिवार की वार्षिक आय ₹2.5 लाख से कम\n• आधार कार्ड और बैंक खाता आवश्यक\n• परिवार में कोई आयकर दाता न हो',
      targetBeneficiaries: ['Women aged 21-60', 'Madhya Pradesh residents'],
      targetBeneficiariesHindi: ['21-60 वर्ष की महिलाएं', 'मध्य प्रदेश निवासी'],
      requiredDocuments: [
        SchemeDocument(name: 'Aadhaar Card', nameHindi: 'आधार कार्ड'),
        SchemeDocument(name: 'Domicile Certificate', nameHindi: 'मूल निवास प्रमाण पत्र'),
        SchemeDocument(name: 'Income Certificate', nameHindi: 'आय प्रमाण पत्र'),
        SchemeDocument(name: 'Bank Passbook', nameHindi: 'बैंक पासबुक'),
        SchemeDocument(name: 'Samagra ID', nameHindi: 'समग्र आईडी'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Visit Camp or Portal',
          titleHindi: 'कैंप या पोर्टल पर जाएं',
          description: 'Visit designated camps or cmladlibahna.mp.gov.in',
          descriptionHindi: 'निर्धारित कैंपों या cmladlibahna.mp.gov.in पर जाएं',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Fill Application Form',
          titleHindi: 'आवेदन पत्र भरें',
          description: 'Fill the application form with required details',
          descriptionHindi: 'आवश्यक विवरण के साथ आवेदन पत्र भरें',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Submit with Documents',
          titleHindi: 'दस्तावेजों के साथ जमा करें',
          description: 'Submit form with all required documents',
          descriptionHindi: 'सभी आवश्यक दस्तावेजों के साथ फॉर्म जमा करें',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '0755-2555999',
        website: 'https://cmladlibahna.mp.gov.in',
      ),
      officialWebsite: 'https://cmladlibahna.mp.gov.in',
      hasApplicationFee: false,
      icon: '👩',
      color: 'pink',
      isFeatured: true,
      tags: ['women', 'mp', 'महिला', 'मध्य प्रदेश'],
    ),
    
    // ----------------------------------------------------------
    // MAHARASHTRA - Ladki Bahin Yojana
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'mh_ladki_bahin',
      schemeName: 'Mukhyamantri Majhi Ladki Bahin Yojana',
      schemeNameHindi: 'मुख्यमंत्री माझी लाडकी बहीण योजना',
      shortDescription: 'Financial assistance of ₹1,500/month to women',
      shortDescriptionHindi: 'महिलाओं को ₹1,500/माह की वित्तीय सहायता',
      level: 'state',
      state: 'Maharashtra',
      category: 'women_child',
      fullDescription: 'Mukhyamantri Majhi Ladki Bahin Yojana is a scheme by the Maharashtra government to provide financial assistance of ₹1,500 per month to eligible women aged 21-65 years.',
      fullDescriptionHindi: 'मुख्यमंत्री माझी लाडकी बहीण योजना महाराष्ट्र सरकार की एक योजना है जो 21-65 वर्ष की पात्र महिलाओं को ₹1,500 प्रति माह की वित्तीय सहायता प्रदान करती है।',
      benefits: [
        SchemeBenefit(
          title: 'Monthly Assistance',
          description: '₹1,500 per month directly to bank account',
          amount: '₹1,500/month',
          type: 'financial',
        ),
      ],
      eligibility: SchemeEligibility(
        ageMin: 21,
        ageMax: 65,
        gender: 'female',
        incomeLimit: 250000,
        domicileState: 'Maharashtra',
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• महाराष्ट्र की मूल निवासी महिला\n• आयु 21-65 वर्ष\n• परिवार की वार्षिक आय ₹2.5 लाख से कम\n• आधार कार्ड और बैंक खाता आवश्यक',
      targetBeneficiaries: ['Women aged 21-65', 'Maharashtra residents'],
      targetBeneficiariesHindi: ['21-65 वर्ष की महिलाएं', 'महाराष्ट्र निवासी'],
      requiredDocuments: [
        SchemeDocument(name: 'Aadhaar Card', nameHindi: 'आधार कार्ड'),
        SchemeDocument(name: 'Domicile Certificate', nameHindi: 'मूल निवास प्रमाण पत्र'),
        SchemeDocument(name: 'Income Certificate', nameHindi: 'आय प्रमाण पत्र'),
        SchemeDocument(name: 'Bank Passbook', nameHindi: 'बैंक पासबुक'),
        SchemeDocument(name: 'Ration Card', nameHindi: 'राशन कार्ड'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Visit Official Portal',
          titleHindi: 'आधिकारिक पोर्टल पर जाएं',
          description: 'Go to ladakibahin.maharashtra.gov.in',
          descriptionHindi: 'ladakibahin.maharashtra.gov.in पर जाएं',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Fill Application',
          titleHindi: 'आवेदन भरें',
          description: 'Complete the online application form',
          descriptionHindi: 'ऑनलाइन आवेदन पत्र पूरा करें',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Submit Documents',
          titleHindi: 'दस्तावेज जमा करें',
          description: 'Upload required documents and submit',
          descriptionHindi: 'आवश्यक दस्तावेज अपलोड करें और जमा करें',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '181',
        website: 'https://ladakibahin.maharashtra.gov.in',
      ),
      officialWebsite: 'https://ladakibahin.maharashtra.gov.in',
      hasApplicationFee: false,
      icon: '👩',
      color: 'pink',
      isFeatured: true,
      tags: ['women', 'maharashtra', 'महिला', 'महाराष्ट्र'],
    ),
    
    // ----------------------------------------------------------
    // UTTAR PRADESH - Kanya Sumangala Yojana
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'up_kanya_sumangala',
      schemeName: 'Mukhyamantri Kanya Sumangala Yojana',
      schemeNameHindi: 'मुख्यमंत्री कन्या सुमंगला योजना',
      shortDescription: 'Financial assistance up to ₹25,000 for girl child',
      shortDescriptionHindi: 'बालिका के लिए ₹25,000 तक की वित्तीय सहायता',
      level: 'state',
      state: 'Uttar Pradesh',
      category: 'women_child',
      fullDescription: 'Mukhyamantri Kanya Sumangala Yojana is a scheme by the Uttar Pradesh government to provide financial assistance to girl children from birth to graduation. The scheme provides ₹25,000 in 6 stages.',
      fullDescriptionHindi: 'मुख्यमंत्री कन्या सुमंगला योजना उत्तर प्रदेश सरकार की एक योजना है जो जन्म से स्नातक तक बालिकाओं को वित्तीय सहायता प्रदान करती है। यह योजना 6 चरणों में ₹25,000 प्रदान करती है।',
      benefits: [
        SchemeBenefit(
          title: 'Total Assistance',
          description: '₹25,000 in 6 stages',
          amount: '₹25,000',
          type: 'financial',
        ),
        SchemeBenefit(
          title: 'Stage-wise Benefits',
          description: '₹5,000 at birth, ₹2,000 at each stage',
          type: 'financial',
        ),
      ],
      eligibility: SchemeEligibility(
        ageMin: 0,
        ageMax: 22,
        gender: 'female',
        incomeLimit: 300000,
        domicileState: 'Uttar Pradesh',
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• उत्तर प्रदेश की मूल निवासी बालिका\n• परिवार की वार्षिक आय ₹3 लाख से कम\n• अधिकतम 2 बालिकाओं के लिए लाभ\n• जन्म से स्नातक तक',
      targetBeneficiaries: ['Girl children', 'UP residents'],
      targetBeneficiariesHindi: ['बालिकाएं', 'उत्तर प्रदेश निवासी'],
      requiredDocuments: [
        SchemeDocument(name: 'Birth Certificate', nameHindi: 'जन्म प्रमाण पत्र'),
        SchemeDocument(name: 'Aadhaar Card', nameHindi: 'आधार कार्ड'),
        SchemeDocument(name: 'Income Certificate', nameHindi: 'आय प्रमाण पत्र'),
        SchemeDocument(name: 'Domicile Certificate', nameHindi: 'मूल निवास प्रमाण पत्र'),
        SchemeDocument(name: 'Bank Passbook', nameHindi: 'बैंक पासबुक'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Visit Official Portal',
          titleHindi: 'आधिकारिक पोर्टल पर जाएं',
          description: 'Go to mksy.up.gov.in',
          descriptionHindi: 'mksy.up.gov.in पर जाएं',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Fill Application',
          titleHindi: 'आवेदन भरें',
          description: 'Complete the online application form',
          descriptionHindi: 'ऑनलाइन आवेदन पत्र पूरा करें',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Submit Documents',
          titleHindi: 'दस्तावेज जमा करें',
          description: 'Upload required documents and submit',
          descriptionHindi: 'आवश्यक दस्तावेज अपलोड करें और जमा करें',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '1800-180-5333',
        website: 'https://mksy.up.gov.in',
      ),
      officialWebsite: 'https://mksy.up.gov.in',
      hasApplicationFee: false,
      icon: '👧',
      color: 'pink',
      isFeatured: true,
      tags: ['girl child', 'up', 'बालिका', 'उत्तर प्रदेश'],
    ),
    
    // ----------------------------------------------------------
    // RAJASTHAN - Chiranjeevi Yojana
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'rj_chiranjeevi',
      schemeName: 'Mukhyamantri Chiranjeevi Yojana',
      schemeNameHindi: 'मुख्यमंत्री चिरंजीवी योजना',
      shortDescription: 'Health insurance cover of ₹25 lakh per family',
      shortDescriptionHindi: 'प्रति परिवार ₹25 लाख का स्वास्थ्य बीमा',
      level: 'state',
      state: 'Rajasthan',
      category: 'health',
      fullDescription: 'Mukhyamantri Chiranjeevi Yojana is a scheme by the Rajasthan government to provide health insurance cover of ₹25 lakh per family per year to all residents of Rajasthan.',
      fullDescriptionHindi: 'मुख्यमंत्री चिरंजीवी योजना राजस्थान सरकार की एक योजना है जो राजस्थान के सभी निवासियों को प्रति परिवार प्रति वर्ष ₹25 लाख का स्वास्थ्य बीमा कवर प्रदान करती है।',
      benefits: [
        SchemeBenefit(
          title: 'Health Cover',
          description: '₹25 lakh per family per year',
          amount: '₹25,00,000',
          type: 'financial',
        ),
        SchemeBenefit(
          title: 'Cashless Treatment',
          description: 'At government and empanelled private hospitals',
          type: 'service',
        ),
      ],
      eligibility: SchemeEligibility(
        domicileState: 'Rajasthan',
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• राजस्थान का मूल निवासी\n• आयु की कोई सीमा नहीं\n• जन आधार कार्ड आवश्यक\n• परिवार के सभी सदस्य पात्र',
      targetBeneficiaries: ['Rajasthan residents', 'All age groups'],
      targetBeneficiariesHindi: ['राजस्थान निवासी', 'सभी आयु वर्ग'],
      requiredDocuments: [
        SchemeDocument(name: 'Jan Aadhaar Card', nameHindi: 'जन आधार कार्ड'),
        SchemeDocument(name: 'Aadhaar Card', nameHindi: 'आधार कार्ड'),
        SchemeDocument(name: 'Domicile Certificate', nameHindi: 'मूल निवास प्रमाण पत्र'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Visit Official Portal',
          titleHindi: 'आधिकारिक पोर्टल पर जाएं',
          description: 'Go to health.rajasthan.gov.in',
          descriptionHindi: 'health.rajasthan.gov.in पर जाएं',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Register with Jan Aadhaar',
          titleHindi: 'जन आधार से पंजीकरण करें',
          description: 'Register using your Jan Aadhaar number',
          descriptionHindi: 'अपने जन आधार नंबर का उपयोग करके पंजीकरण करें',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Get Insurance Card',
          titleHindi: 'बीमा कार्ड प्राप्त करें',
          description: 'Download your Chiranjeevi card',
          descriptionHindi: 'अपना चिरंजीवी कार्ड डाउनलोड करें',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '1800-180-6127',
        website: 'https://health.rajasthan.gov.in',
      ),
      officialWebsite: 'https://health.rajasthan.gov.in',
      hasApplicationFee: false,
      icon: '🏥',
      color: 'teal',
      isFeatured: true,
      tags: ['health', 'rajasthan', 'स्वास्थ्य', 'राजस्थान'],
    ),
    
    // ----------------------------------------------------------
    // TAMIL NADU - Kalaignar Magalir Urimai Thogai
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'tn_kalaignar_magalir',
      schemeName: 'Kalaignar Magalir Urimai Thogai',
      schemeNameHindi: 'कलैग्नार मगलिर उरिमै थोगै',
      shortDescription: 'Monthly assistance of ₹1,000 to women heads of families',
      shortDescriptionHindi: 'परिवार की महिला मुखियाओं को ₹1,000/माह की सहायता',
      level: 'state',
      state: 'Tamil Nadu',
      category: 'women_child',
      fullDescription: 'Kalaignar Magalir Urimai Thogai is a scheme by the Tamil Nadu government to provide ₹1,000 per month to eligible women heads of families in Tamil Nadu.',
      fullDescriptionHindi: 'कलैग्नार मगलिर उरिमै थोगै तमिलनाडु सरकार की एक योजना है जो तमिलनाडु में पात्र महिला परिवार मुखियाओं को ₹1,000 प्रति माह प्रदान करती है।',
      benefits: [
        SchemeBenefit(
          title: 'Monthly Assistance',
          description: '₹1,000 per month',
          amount: '₹1,000/month',
          type: 'financial',
        ),
      ],
      eligibility: SchemeEligibility(
        ageMin: 21,
        gender: 'female',
        incomeLimit: 250000,
        domicileState: 'Tamil Nadu',
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• तमिलनाडु की मूल निवासी महिला\n• आयु 21 वर्ष से अधिक\n• परिवार की वार्षिक आय ₹2.5 लाख से कम\n• परिवार की मुखिया महिला हो',
      targetBeneficiaries: ['Women heads of families', 'Tamil Nadu residents'],
      targetBeneficiariesHindi: ['परिवार की महिला मुखिया', 'तमिलनाडु निवासी'],
      requiredDocuments: [
        SchemeDocument(name: 'Aadhaar Card', nameHindi: 'आधार कार्ड'),
        SchemeDocument(name: 'Ration Card', nameHindi: 'राशन कार्ड'),
        SchemeDocument(name: 'Income Certificate', nameHindi: 'आय प्रमाण पत्र'),
        SchemeDocument(name: 'Bank Passbook', nameHindi: 'बैंक पासबुक'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Visit e-Sevai Center',
          titleHindi: 'ई-सेवा केंद्र पर जाएं',
          description: 'Visit nearest e-Sevai center or apply online',
          descriptionHindi: 'निकटतम ई-सेवा केंद्र पर जाएं या ऑनलाइन आवेदन करें',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Fill Application',
          titleHindi: 'आवेदन भरें',
          description: 'Complete the application form',
          descriptionHindi: 'आवेदन पत्र पूरा करें',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Submit Documents',
          titleHindi: 'दस्तावेज जमा करें',
          description: 'Submit required documents',
          descriptionHindi: 'आवश्यक दस्तावेज जमा करें',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '1100',
        website: 'https://kmut.tn.gov.in',
      ),
      officialWebsite: 'https://kmut.tn.gov.in',
      hasApplicationFee: false,
      icon: '👩',
      color: 'pink',
      isFeatured: true,
      tags: ['women', 'tamil nadu', 'महिला', 'तमिलनाडु'],
    ),
    
    // ----------------------------------------------------------
    // KARNATAKA - Gruha Lakshmi
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'ka_gruha_lakshmi',
      schemeName: 'Gruha Lakshmi Yojana',
      schemeNameHindi: 'गृह लक्ष्मी योजना',
      shortDescription: 'Monthly assistance of ₹2,000 to women heads of families',
      shortDescriptionHindi: 'परिवार की महिला मुखियाओं को ₹2,000/माह की सहायता',
      level: 'state',
      state: 'Karnataka',
      category: 'women_child',
      fullDescription: 'Gruha Lakshmi Yojana is a scheme by the Karnataka government to provide ₹2,000 per month to women heads of families in Karnataka.',
      fullDescriptionHindi: 'गृह लक्ष्मी योजना कर्नाटक सरकार की एक योजना है जो कर्नाटक में महिला परिवार मुखियाओं को ₹2,000 प्रति माह प्रदान करती है।',
      benefits: [
        SchemeBenefit(
          title: 'Monthly Assistance',
          description: '₹2,000 per month',
          amount: '₹2,000/month',
          type: 'financial',
        ),
      ],
      eligibility: SchemeEligibility(
        ageMin: 18,
        gender: 'female',
        domicileState: 'Karnataka',
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• कर्नाटक की मूल निवासी महिला\n• परिवार की मुखिया महिला\n• BPL/APL परिवार\n• आधार कार्ड और बैंक खाता आवश्यक',
      targetBeneficiaries: ['Women heads of families', 'Karnataka residents'],
      targetBeneficiariesHindi: ['परिवार की महिला मुखिया', 'कर्नाटक निवासी'],
      requiredDocuments: [
        SchemeDocument(name: 'Aadhaar Card', nameHindi: 'आधार कार्ड'),
        SchemeDocument(name: 'Ration Card', nameHindi: 'राशन कार्ड'),
        SchemeDocument(name: 'Bank Passbook', nameHindi: 'बैंक पासबुक'),
        SchemeDocument(name: 'Address Proof', nameHindi: 'पता प्रमाण'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Visit Official Portal',
          titleHindi: 'आधिकारिक पोर्टल पर जाएं',
          description: 'Go to sevasindhuservices.karnataka.gov.in',
          descriptionHindi: 'sevasindhuservices.karnataka.gov.in पर जाएं',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Fill Application',
          titleHindi: 'आवेदन भरें',
          description: 'Complete the online application form',
          descriptionHindi: 'ऑनलाइन आवेदन पत्र पूरा करें',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Submit Documents',
          titleHindi: 'दस्तावेज जमा करें',
          description: 'Upload required documents',
          descriptionHindi: 'आवश्यक दस्तावेज अपलोड करें',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '1902',
        website: 'https://sevasindhuservices.karnataka.gov.in',
      ),
      officialWebsite: 'https://sevasindhuservices.karnataka.gov.in',
      hasApplicationFee: false,
      icon: '👩',
      color: 'pink',
      isFeatured: true,
      tags: ['women', 'karnataka', 'महिला', 'कर्नाटक'],
    ),
    
    // ----------------------------------------------------------
    // BIHAR - Mukhyamantri Kanya Vivah Yojana
    // ----------------------------------------------------------
    GovernmentScheme(
      schemeId: 'br_kanya_vivah',
      schemeName: 'Mukhyamantri Kanya Vivah Yojana',
      schemeNameHindi: 'मुख्यमंत्री कन्या विवाह योजना',
      shortDescription: 'Financial assistance of ₹5,000 for daughter\'s marriage',
      shortDescriptionHindi: 'बेटी के विवाह के लिए ₹5,000 की वित्तीय सहायता',
      level: 'state',
      state: 'Bihar',
      category: 'women_child',
      fullDescription: 'Mukhyamantri Kanya Vivah Yojana is a scheme by the Bihar government to provide financial assistance of ₹5,000 to families below poverty line for their daughter\'s marriage.',
      fullDescriptionHindi: 'मुख्यमंत्री कन्या विवाह योजना बिहार सरकार की एक योजना है जो गरीबी रेखा से नीचे के परिवारों को उनकी बेटी के विवाह के लिए ₹5,000 की वित्तीय सहायता प्रदान करती है।',
      benefits: [
        SchemeBenefit(
          title: 'Marriage Assistance',
          description: '₹5,000 for daughter\'s marriage',
          amount: '₹5,000',
          type: 'financial',
        ),
      ],
      eligibility: SchemeEligibility(
        ageMin: 18,
        gender: 'female',
        incomeLimit: 60000,
        domicileState: 'Bihar',
        bplRequired: true,
        aadhaarRequired: true,
      ),
      eligibilityDetailsHindi: '• बिहार की मूल निवासी\n• BPL परिवार\n• कन्या की आयु 18 वर्ष से अधिक\n• अधिकतम 2 बेटियों के लिए लाभ',
      targetBeneficiaries: ['BPL families', 'Bihar residents'],
      targetBeneficiariesHindi: ['BPL परिवार', 'बिहार निवासी'],
      requiredDocuments: [
        SchemeDocument(name: 'Aadhaar Card', nameHindi: 'आधार कार्ड'),
        SchemeDocument(name: 'BPL Card', nameHindi: 'BPL कार्ड'),
        SchemeDocument(name: 'Age Proof', nameHindi: 'आयु प्रमाण'),
        SchemeDocument(name: 'Bank Passbook', nameHindi: 'बैंक पासबुक'),
      ],
      applicationSteps: [
        SchemeApplicationStep(
          stepNumber: 1,
          title: 'Visit Block Office',
          titleHindi: 'प्रखंड कार्यालय पर जाएं',
          description: 'Visit nearest block office or apply online',
          descriptionHindi: 'निकटतम प्रखंड कार्यालय पर जाएं या ऑनलाइन आवेदन करें',
        ),
        SchemeApplicationStep(
          stepNumber: 2,
          title: 'Fill Application',
          titleHindi: 'आवेदन भरें',
          description: 'Fill the application form',
          descriptionHindi: 'आवेदन पत्र भरें',
        ),
        SchemeApplicationStep(
          stepNumber: 3,
          title: 'Submit Documents',
          titleHindi: 'दस्तावेज जमा करें',
          description: 'Submit required documents',
          descriptionHindi: 'आवश्यक दस्तावेज जमा करें',
        ),
      ],
      contactInfo: SchemeContactInfo(
        helpline: '1800-345-6222',
        website: 'https://state.bihar.gov.in',
      ),
      officialWebsite: 'https://state.bihar.gov.in',
      hasApplicationFee: false,
      icon: '💒',
      color: 'pink',
      isFeatured: false,
      tags: ['marriage', 'bihar', 'विवाह', 'बिहार'],
    ),
  ];

  // ============================================================
  // GETTER METHODS
  // ============================================================
  
  static List<GovernmentScheme> get allSchemes => [
    ...centralSchemes,
    ...stateSchemes,
  ];
  
  static List<GovernmentScheme> get featuredSchemes => 
    allSchemes.where((s) => s.isFeatured).toList();
  
  static List<GovernmentScheme> getSchemesByCategory(String category) =>
    allSchemes.where((s) => s.category == category).toList();
  
  static List<GovernmentScheme> getSchemesByLevel(String level) {
    if (level == 'central') return centralSchemes;
    if (level == 'state') return stateSchemes;
    return allSchemes;
  }
  
  static List<GovernmentScheme> getSchemesByState(String state) =>
    stateSchemes.where((s) => s.state?.toLowerCase() == state.toLowerCase()).toList();
  
  static GovernmentScheme? getSchemeById(String schemeId) {
    try {
      return allSchemes.firstWhere((s) => s.schemeId == schemeId);
    } catch (e) {
      return null;
    }
  }
  
  static List<GovernmentScheme> searchSchemes(String query) {
    if (query.isEmpty) return allSchemes;
    final q = query.toLowerCase();
    return allSchemes.where((s) =>
      s.schemeName.toLowerCase().contains(q) ||
      s.schemeNameHindi.contains(q) ||
      s.shortDescription.toLowerCase().contains(q) ||
      s.shortDescriptionHindi.contains(q) ||
      s.tags.any((t) => t.toLowerCase().contains(q))
    ).toList();
  }
  
  static List<String> get allStates {
    final states = stateSchemes.map((s) => s.state).whereType<String>().toSet().toList();
    states.sort();
    return states;
  }
  
  static List<Map<String, dynamic>> get categories => [
    {'id': 'agriculture', 'name': 'Agriculture', 'nameHindi': 'कृषि', 'icon': '🌾'},
    {'id': 'education', 'name': 'Education', 'nameHindi': 'शिक्षा', 'icon': '📚'},
    {'id': 'health', 'name': 'Health', 'nameHindi': 'स्वास्थ्य', 'icon': '🏥'},
    {'id': 'housing', 'name': 'Housing', 'nameHindi': 'आवास', 'icon': '🏠'},
    {'id': 'employment', 'name': 'Employment', 'nameHindi': 'रोजगार', 'icon': '💼'},
    {'id': 'women_child', 'name': 'Women & Child', 'nameHindi': 'महिला एवं बाल', 'icon': '👩'},
    {'id': 'social_welfare', 'name': 'Social Welfare', 'nameHindi': 'समाज कल्याण', 'icon': '🤝'},
    {'id': 'financial_inclusion', 'name': 'Financial Inclusion', 'nameHindi': 'वित्तीय समावेशन', 'icon': '💰'},
    {'id': 'pension', 'name': 'Pension', 'nameHindi': 'पेंशन', 'icon': '👴'},
    {'id': 'insurance', 'name': 'Insurance', 'nameHindi': 'बीमा', 'icon': '🛡️'},
    {'id': 'skill_development', 'name': 'Skill Development', 'nameHindi': 'कौशल विकास', 'icon': '🎓'},
    {'id': 'entrepreneurship', 'name': 'Entrepreneurship', 'nameHindi': 'उद्यमिता', 'icon': '🚀'},
    {'id': 'disability', 'name': 'Disability', 'nameHindi': 'विकलांगता', 'icon': '♿'},
    {'id': 'sc_st_welfare', 'name': 'SC/ST Welfare', 'nameHindi': 'अनुसूचित जाति/जनजाति कल्याण', 'icon': '📋'},
    {'id': 'minority_welfare', 'name': 'Minority Welfare', 'nameHindi': 'अल्पसंख्यक कल्याण', 'icon': '🕌'},
    {'id': 'other', 'name': 'Other', 'nameHindi': 'अन्य', 'icon': '📌'},
  ];

  // ============================================================
  // ✅ DEBUG/LOGGING METHOD (replaces invalid top-level print)
  // ============================================================
  static void logMasterDataLoaded() {
    debugPrint(
      "✅ Schemes Master Data Loaded: ${SchemesMasterData.allSchemes.length} schemes",
    );
  }
}