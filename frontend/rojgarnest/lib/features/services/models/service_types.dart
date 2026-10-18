// lib/features/services/models/service_types.dart

import 'package:flutter/material.dart'; // ✅ ADD THIS IMPORT

class ServiceType {
  final String id;
  final String name;
  final String icon;
  final String description;
  final List<ServiceSubType> subTypes;

  ServiceType({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.subTypes,
  });

  // ✅ Convert to JSON for API requests
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'description': description,
    'sub_types': subTypes.map((s) => s.toJson()).toList(),
  };

  // ✅ Create from JSON (for API responses)
  factory ServiceType.fromJson(Map<String, dynamic> json) {
    return ServiceType(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '📄',
      description: json['description'] ?? '',
      subTypes: (json['sub_types'] as List? ?? [])
          .map((s) => ServiceSubType.fromJson(s))
          .toList(),
    );
  }
}

class ServiceSubType {
  final String id;
  final String name;
  final String description;
  final List<RequiredField> requiredFields;
  final List<String> requiredDocuments;

  ServiceSubType({
    required this.id,
    required this.name,
    required this.description,
    required this.requiredFields,
    required this.requiredDocuments,
  });

  // ✅ Convert to JSON for API requests
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'required_fields': requiredFields.map((f) => f.toJson()).toList(),
    'required_documents': requiredDocuments,
  };

  // ✅ Create from JSON (for API responses)
  factory ServiceSubType.fromJson(Map<String, dynamic> json) {
    return ServiceSubType(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      requiredFields: (json['required_fields'] as List? ?? [])
          .map((f) => RequiredField.fromJson(f))
          .toList(),
      requiredDocuments: (json['required_documents'] as List? ?? [])
          .map((d) => d.toString())
          .toList(),
    );
  }
}

class RequiredField {
  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final String? hintText;

  RequiredField({
    required this.key,
    required this.label,
    required this.type,
    this.required = true,
    this.hintText,
  });

  // ✅ Convert to JSON for API requests
  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type.value,
    'required': required,
    'hint_text': hintText,
  };

  // ✅ Create from JSON (for API responses)
  factory RequiredField.fromJson(Map<String, dynamic> json) {
    return RequiredField(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      type: FieldTypeExtension.fromString(json['type'] ?? 'text'),
      required: json['required'] ?? true,
      hintText: json['hint_text'],
    );
  }
}

enum FieldType {
  text,
  number,
  email,
  phone,
  password,
  date,
  dropdown,
  file,
}

// ==================== FIELD TYPE EXTENSION ====================

extension FieldTypeExtension on FieldType {
  String get value {
    switch (this) {
      case FieldType.text:
        return 'text';
      case FieldType.number:
        return 'number';
      case FieldType.email:
        return 'email';
      case FieldType.phone:
        return 'phone';
      case FieldType.password:
        return 'password';
      case FieldType.date:
        return 'date';
      case FieldType.dropdown:
        return 'dropdown';
      case FieldType.file:
        return 'file';
    }
  }

  TextInputType get keyboardType {
    switch (this) {
      case FieldType.number:
        return TextInputType.number;
      case FieldType.email:
        return TextInputType.emailAddress;
      case FieldType.phone:
        return TextInputType.phone;
      case FieldType.text:
      case FieldType.password:
      case FieldType.date:
      case FieldType.dropdown:
      case FieldType.file:
        return TextInputType.text;
    }
  }

  static FieldType fromString(String value) {
    switch (value) {
      case 'number':
        return FieldType.number;
      case 'email':
        return FieldType.email;
      case 'phone':
        return FieldType.phone;
      case 'password':
        return FieldType.password;
      case 'date':
        return FieldType.date;
      case 'dropdown':
        return FieldType.dropdown;
      case 'file':
        return FieldType.file;
      default:
        return FieldType.text;
    }
  }
}

// ==================== MASTER SERVICE DATA ====================

class ServiceMasterData {
  static final List<ServiceType> services = [
    // ==================== PAN CARD SERVICES ====================
    ServiceType(
      id: 'pan',
      name: 'PAN Card',
      icon: '🪪',
      description: 'PAN Card related services',
      subTypes: [
        ServiceSubType(
          id: 'pan_new',
          name: 'New PAN Card Application',
          description: 'Apply for a new PAN Card',
          requiredFields: [
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
            RequiredField(key: 'dob', label: 'Date of Birth', type: FieldType.date),
            RequiredField(key: 'father_name', label: "Father's Name", type: FieldType.text),
            RequiredField(key: 'mobile', label: 'Mobile Number', type: FieldType.phone),
            RequiredField(key: 'email', label: 'Email Address', type: FieldType.email),
            RequiredField(key: 'aadhar_number', label: 'Aadhaar Number', type: FieldType.text),
          ],
          requiredDocuments: [
            'Aadhaar Card',
            'Passport Size Photo',
            'Address Proof',
          ],
        ),
        ServiceSubType(
          id: 'pan_renew',
          name: 'PAN Card Renewal',
          description: 'Renew your existing PAN Card',
          requiredFields: [
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
            RequiredField(key: 'pan_number', label: 'Existing PAN Number', type: FieldType.text),
            RequiredField(key: 'mobile', label: 'Mobile Number', type: FieldType.phone),
            RequiredField(key: 'email', label: 'Email Address', type: FieldType.email),
          ],
          requiredDocuments: [
            'Existing PAN Card',
            'Passport Size Photo',
          ],
        ),
        ServiceSubType(
          id: 'pan_aadhar_link',
          name: 'PAN - Aadhaar Linking',
          description: 'Link your PAN with Aadhaar',
          requiredFields: [
            RequiredField(key: 'pan_number', label: 'PAN Number', type: FieldType.text),
            RequiredField(key: 'aadhar_number', label: 'Aadhaar Number', type: FieldType.text),
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
          ],
          requiredDocuments: [
            'PAN Card',
            'Aadhaar Card',
          ],
        ),
        ServiceSubType(
          id: 'pan_correction',
          name: 'PAN Card Correction',
          description: 'Correct details in PAN Card',
          requiredFields: [
            RequiredField(key: 'pan_number', label: 'PAN Number', type: FieldType.text),
            RequiredField(key: 'field_to_correct', label: 'Field to Correct', type: FieldType.text),
            RequiredField(key: 'correct_value', label: 'Correct Value', type: FieldType.text),
          ],
          requiredDocuments: [
            'Existing PAN Card',
            'Proof of Correct Information',
          ],
        ),
      ],
    ),

    // ==================== AADHAAR SERVICES ====================
    ServiceType(
      id: 'aadhar',
      name: 'Aadhaar',
      icon: '🪪',
      description: 'Aadhaar related services',
      subTypes: [
        ServiceSubType(
          id: 'aadhar_new',
          name: 'New Aadhaar Enrollment',
          description: 'Apply for new Aadhaar',
          requiredFields: [
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
            RequiredField(key: 'dob', label: 'Date of Birth', type: FieldType.date),
            RequiredField(key: 'gender', label: 'Gender', type: FieldType.dropdown),
            RequiredField(key: 'mobile', label: 'Mobile Number', type: FieldType.phone),
            RequiredField(key: 'email', label: 'Email Address', type: FieldType.email),
          ],
          requiredDocuments: [
            'Birth Certificate',
            'Identity Proof',
            'Address Proof',
          ],
        ),
        ServiceSubType(
          id: 'aadhar_update',
          name: 'Aadhaar Update/Correction',
          description: 'Update or correct Aadhaar details',
          requiredFields: [
            RequiredField(key: 'aadhar_number', label: 'Aadhaar Number', type: FieldType.text),
            RequiredField(key: 'field_to_update', label: 'Field to Update', type: FieldType.text),
            RequiredField(key: 'new_value', label: 'New Value', type: FieldType.text),
          ],
          requiredDocuments: [
            'Aadhaar Card',
            'Proof of New Information',
          ],
        ),
        ServiceSubType(
          id: 'aadhar_address_update',
          name: 'Aadhaar Address Update',
          description: 'Update address in Aadhaar',
          requiredFields: [
            RequiredField(key: 'aadhar_number', label: 'Aadhaar Number', type: FieldType.text),
            RequiredField(key: 'new_address', label: 'New Address', type: FieldType.text),
          ],
          requiredDocuments: [
            'Aadhaar Card',
            'Address Proof',
          ],
        ),
      ],
    ),

    // ==================== EPF SERVICES ====================
    ServiceType(
      id: 'epf',
      name: 'EPF / PF',
      icon: '🏦',
      description: 'EPF (Employees Provident Fund) services',
      subTypes: [
        ServiceSubType(
          id: 'pf_withdrawal',
          name: 'PF Withdrawal',
          description: 'Withdraw PF amount',
          requiredFields: [
            RequiredField(key: 'uan_number', label: 'UAN Number', type: FieldType.text),
            RequiredField(key: 'pan_number', label: 'PAN Number', type: FieldType.text),
            RequiredField(key: 'bank_account', label: 'Bank Account Number', type: FieldType.text),
            RequiredField(key: 'ifsc_code', label: 'IFSC Code', type: FieldType.text),
            RequiredField(key: 'amount', label: 'Amount to Withdraw', type: FieldType.number),
          ],
          requiredDocuments: [
            'UAN Card',
            'PAN Card',
            'Bank Account Proof',
            'Cancelled Cheque',
          ],
        ),
        ServiceSubType(
          id: 'pf_transfer',
          name: 'PF Transfer',
          description: 'Transfer PF from one company to another',
          requiredFields: [
            RequiredField(key: 'uan_number', label: 'UAN Number', type: FieldType.text),
            RequiredField(key: 'previous_employer', label: 'Previous Employer', type: FieldType.text),
            RequiredField(key: 'new_employer', label: 'New Employer', type: FieldType.text),
          ],
          requiredDocuments: [
            'UAN Card',
            'Previous Employer PF Statement',
            'New Employer Details',
          ],
        ),
        ServiceSubType(
          id: 'pf_claim',
          name: 'PF Claim / Final Settlement',
          description: 'Final PF settlement after job change',
          requiredFields: [
            RequiredField(key: 'uan_number', label: 'UAN Number', type: FieldType.text),
            RequiredField(key: 'pan_number', label: 'PAN Number', type: FieldType.text),
            RequiredField(key: 'aadhar_number', label: 'Aadhaar Number', type: FieldType.text),
          ],
          requiredDocuments: [
            'UAN Card',
            'PAN Card',
            'Aadhaar Card',
            'Bank Account Proof',
          ],
        ),
        ServiceSubType(
          id: 'pf_pension',
          name: 'Pension Form (EPS)',
          description: 'Apply for Employee Pension Scheme',
          requiredFields: [
            RequiredField(key: 'uan_number', label: 'UAN Number', type: FieldType.text),
            RequiredField(key: 'pan_number', label: 'PAN Number', type: FieldType.text),
            RequiredField(key: 'service_years', label: 'Years of Service', type: FieldType.number),
          ],
          requiredDocuments: [
            'UAN Card',
            'PAN Card',
            'Service Certificate',
          ],
        ),
        ServiceSubType(
          id: 'pf_nomination',
          name: 'PF Nomination Update',
          description: 'Update/Add nominee for PF',
          requiredFields: [
            RequiredField(key: 'uan_number', label: 'UAN Number', type: FieldType.text),
            RequiredField(key: 'nominee_name', label: 'Nominee Name', type: FieldType.text),
            RequiredField(key: 'nominee_relation', label: 'Relationship', type: FieldType.text),
          ],
          requiredDocuments: [
            'UAN Card',
            'Nominee ID Proof',
          ],
        ),
      ],
    ),

    // ==================== PASSPORT SERVICES ====================
    ServiceType(
      id: 'passport',
      name: 'Passport',
      icon: '🛂',
      description: 'Passport related services',
      subTypes: [
        ServiceSubType(
          id: 'passport_new',
          name: 'New Passport Application',
          description: 'Apply for new passport',
          requiredFields: [
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
            RequiredField(key: 'dob', label: 'Date of Birth', type: FieldType.date),
            RequiredField(key: 'place_of_birth', label: 'Place of Birth', type: FieldType.text),
            RequiredField(key: 'aadhar_number', label: 'Aadhaar Number', type: FieldType.text),
            RequiredField(key: 'pan_number', label: 'PAN Number', type: FieldType.text),
            RequiredField(key: 'mobile', label: 'Mobile Number', type: FieldType.phone),
            RequiredField(key: 'email', label: 'Email Address', type: FieldType.email),
          ],
          requiredDocuments: [
            'Aadhaar Card',
            'PAN Card',
            'Birth Certificate',
            'Address Proof',
          ],
        ),
        ServiceSubType(
          id: 'passport_renew',
          name: 'Passport Renewal',
          description: 'Renew expired passport',
          requiredFields: [
            RequiredField(key: 'passport_number', label: 'Passport Number', type: FieldType.text),
            RequiredField(key: 'expiry_date', label: 'Expiry Date', type: FieldType.date),
          ],
          requiredDocuments: [
            'Old Passport',
            'Aadhaar Card',
          ],
        ),
      ],
    ),

    // ==================== DRIVING LICENSE SERVICES ====================
    ServiceType(
      id: 'driving_license',
      name: 'Driving License',
      icon: '🚗',
      description: 'Driving License services',
      subTypes: [
        ServiceSubType(
          id: 'dl_new',
          name: 'New Driving License',
          description: 'Apply for new driving license',
          requiredFields: [
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
            RequiredField(key: 'dob', label: 'Date of Birth', type: FieldType.date),
            RequiredField(key: 'aadhar_number', label: 'Aadhaar Number', type: FieldType.text),
          ],
          requiredDocuments: [
            'Aadhaar Card',
            'Age Proof',
            'Address Proof',
          ],
        ),
        ServiceSubType(
          id: 'dl_renew',
          name: 'Driving License Renewal',
          description: 'Renew expired driving license',
          requiredFields: [
            RequiredField(key: 'license_number', label: 'License Number', type: FieldType.text),
            RequiredField(key: 'expiry_date', label: 'Expiry Date', type: FieldType.date),
          ],
          requiredDocuments: [
            'Old Driving License',
            'Aadhaar Card',
          ],
        ),
      ],
    ),

    // ==================== VOTER ID SERVICES ====================
    ServiceType(
      id: 'voter_id',
      name: 'Voter ID',
      icon: '🗳️',
      description: 'Voter ID services',
      subTypes: [
        ServiceSubType(
          id: 'voter_new',
          name: 'New Voter ID',
          description: 'Apply for new voter ID',
          requiredFields: [
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
            RequiredField(key: 'dob', label: 'Date of Birth', type: FieldType.date),
            RequiredField(key: 'address', label: 'Address', type: FieldType.text),
          ],
          requiredDocuments: [
            'Aadhaar Card',
            'Address Proof',
          ],
        ),
        ServiceSubType(
          id: 'voter_update',
          name: 'Voter ID Update',
          description: 'Update voter ID details',
          requiredFields: [
            RequiredField(key: 'voter_id', label: 'Voter ID Number', type: FieldType.text),
            RequiredField(key: 'field_to_update', label: 'Field to Update', type: FieldType.text),
          ],
          requiredDocuments: [
            'Voter ID Card',
            'Proof of New Details',
          ],
        ),
      ],
    ),

    // ==================== RATION CARD SERVICES ====================
    ServiceType(
      id: 'ration_card',
      name: 'Ration Card',
      icon: '🪪',
      description: 'Ration Card services',
      subTypes: [
        ServiceSubType(
          id: 'ration_new',
          name: 'New Ration Card',
          description: 'Apply for new ration card',
          requiredFields: [
            RequiredField(key: 'head_name', label: 'Head of Family Name', type: FieldType.text),
            RequiredField(key: 'family_members', label: 'Family Members Count', type: FieldType.number),
            RequiredField(key: 'aadhar_number', label: 'Aadhaar Number', type: FieldType.text),
          ],
          requiredDocuments: [
            'Aadhaar Card',
            'Address Proof',
            'Family Member Details',
          ],
        ),
        ServiceSubType(
          id: 'ration_update',
          name: 'Ration Card Update',
          description: 'Update ration card details',
          requiredFields: [
            RequiredField(key: 'ration_number', label: 'Ration Card Number', type: FieldType.text),
            RequiredField(key: 'field_to_update', label: 'Field to Update', type: FieldType.text),
          ],
          requiredDocuments: [
            'Existing Ration Card',
            'Proof of New Details',
          ],
        ),
      ],
    ),

    // ==================== INCOME CERTIFICATE SERVICES ====================
    ServiceType(
      id: 'income_certificate',
      name: 'Income Certificate',
      icon: '💵',
      description: 'Income Certificate services',
      subTypes: [
        ServiceSubType(
          id: 'income_new',
          name: 'New Income Certificate',
          description: 'Apply for income certificate',
          requiredFields: [
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
            RequiredField(key: 'annual_income', label: 'Annual Income (₹)', type: FieldType.number),
            RequiredField(key: 'aadhar_number', label: 'Aadhaar Number', type: FieldType.text),
          ],
          requiredDocuments: [
            'Aadhaar Card',
            'Income Proof',
            'Address Proof',
          ],
        ),
      ],
    ),

    // ==================== CASTE CERTIFICATE SERVICES ====================
    ServiceType(
      id: 'caste_certificate',
      name: 'Caste Certificate',
      icon: '📜',
      description: 'Caste Certificate services',
      subTypes: [
        ServiceSubType(
          id: 'caste_new',
          name: 'New Caste Certificate',
          description: 'Apply for caste certificate',
          requiredFields: [
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
            RequiredField(key: 'caste', label: 'Caste Category', type: FieldType.dropdown),
            RequiredField(key: 'aadhar_number', label: 'Aadhaar Number', type: FieldType.text),
          ],
          requiredDocuments: [
            'Aadhaar Card',
            'Address Proof',
            "Parent's Caste Proof",
          ],
        ),
      ],
    ),

    // ==================== DOMICILE CERTIFICATE SERVICES ====================
    ServiceType(
      id: 'domicile',
      name: 'Domicile Certificate',
      icon: '🏠',
      description: 'Domicile Certificate services',
      subTypes: [
        ServiceSubType(
          id: 'domicile_new',
          name: 'New Domicile Certificate',
          description: 'Apply for domicile certificate',
          requiredFields: [
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
            RequiredField(key: 'state', label: 'State', type: FieldType.text),
            RequiredField(key: 'aadhar_number', label: 'Aadhaar Number', type: FieldType.text),
          ],
          requiredDocuments: [
            'Aadhaar Card',
            'Address Proof',
            'Residence Proof',
          ],
        ),
      ],
    ),

    // ==================== DISABILITY CERTIFICATE SERVICES ====================
    ServiceType(
      id: 'disability',
      name: 'Disability Certificate',
      icon: '♿',
      description: 'Disability Certificate services',
      subTypes: [
        ServiceSubType(
          id: 'disability_new',
          name: 'New Disability Certificate',
          description: 'Apply for disability certificate',
          requiredFields: [
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
            RequiredField(key: 'disability_type', label: 'Type of Disability', type: FieldType.dropdown),
            RequiredField(key: 'disability_percentage', label: 'Disability Percentage', type: FieldType.number),
            RequiredField(key: 'aadhar_number', label: 'Aadhaar Number', type: FieldType.text),
          ],
          requiredDocuments: [
            'Aadhaar Card',
            'Medical Certificate',
            "Doctor's Prescription",
          ],
        ),
      ],
    ),

    // ==================== BONAFIDE CERTIFICATE SERVICES ====================
    ServiceType(
      id: 'bonafide',
      name: 'Bonafide Certificate',
      icon: '📄',
      description: 'Bonafide Certificate services',
      subTypes: [
        ServiceSubType(
          id: 'bonafide_new',
          name: 'New Bonafide Certificate',
          description: 'Apply for bonafide certificate',
          requiredFields: [
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
            RequiredField(key: 'institute', label: 'Institute Name', type: FieldType.text),
            RequiredField(key: 'course', label: 'Course/Class', type: FieldType.text),
          ],
          requiredDocuments: [
            'Student ID Card',
            'Institute Enrollment Proof',
          ],
        ),
      ],
    ),

    // ==================== GAP CERTIFICATE SERVICES ====================
    ServiceType(
      id: 'gap_certificate',
      name: 'Gap Certificate',
      icon: '⏳',
      description: 'Gap Certificate services',
      subTypes: [
        ServiceSubType(
          id: 'gap_new',
          name: 'New Gap Certificate',
          description: 'Apply for gap certificate',
          requiredFields: [
            RequiredField(key: 'full_name', label: 'Full Name', type: FieldType.text),
            RequiredField(key: 'gap_start_date', label: 'Gap Start Date', type: FieldType.date),
            RequiredField(key: 'gap_end_date', label: 'Gap End Date', type: FieldType.date),
            RequiredField(key: 'reason', label: 'Reason for Gap', type: FieldType.text),
          ],
          requiredDocuments: [
            'Aadhaar Card',
            'Proof of Gap Reason',
          ],
        ),
      ],
    ),
  ];

  // ==================== HELPER METHODS ====================

  static ServiceType? getServiceById(String id) {
    try {
      return services.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  static ServiceSubType? getSubTypeById(String id) {
    for (var service in services) {
      for (var subType in service.subTypes) {
        if (subType.id == id) {
          return subType;
        }
      }
    }
    return null;
  }

  static List<String> getAllServiceIds() {
    return services.map((s) => s.id).toList();
  }

  static List<String> getAllServiceNames() {
    return services.map((s) => s.name).toList();
  }

  static List<String> getAllSubTypeIds() {
    List<String> ids = [];
    for (var service in services) {
      for (var subType in service.subTypes) {
        ids.add(subType.id);
      }
    }
    return ids;
  }

  static List<ServiceType> getServicesWithSubTypes() {
    return services.where((s) => s.subTypes.isNotEmpty).toList();
  }

  static ServiceType? getServiceBySubTypeId(String subTypeId) {
    for (var service in services) {
      for (var subType in service.subTypes) {
        if (subType.id == subTypeId) {
          return service;
        }
      }
    }
    return null;
  }

  // ✅ FIXED: Add getAllServices() method
  static List<ServiceType> getAllServices() {
    return services;
  }
}