# app/modules/services/models/service_types.py
# Service Types Master Data - For Service Payment Integration

from typing import List, Optional, Dict, Any


class ServiceSubType:
    """Service Sub-Type Model"""
    def __init__(self, id: str, name: str, description: str = "", 
                 required_fields: List[Dict] = None, 
                 required_documents: List[str] = None):
        self.id = id
        self.name = name
        self.description = description
        self.required_fields = required_fields or []
        self.required_documents = required_documents or []
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "required_fields": self.required_fields,
            "required_documents": self.required_documents
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ServiceSubType":
        return cls(
            id=data.get("id", ""),
            name=data.get("name", ""),
            description=data.get("description", ""),
            required_fields=data.get("required_fields", []),
            required_documents=data.get("required_documents", [])
        )


class ServiceType:
    """Service Type Model"""
    def __init__(self, id: str, name: str, icon: str = "📄", 
                 description: str = "", sub_types: List[ServiceSubType] = None):
        self.id = id
        self.name = name
        self.icon = icon
        self.description = description
        self.sub_types = sub_types or []
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "icon": self.icon,
            "description": self.description,
            "sub_types": [st.to_dict() for st in self.sub_types]
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ServiceType":
        sub_types = [
            ServiceSubType.from_dict(st) 
            for st in data.get("sub_types", [])
        ]
        return cls(
            id=data.get("id", ""),
            name=data.get("name", ""),
            icon=data.get("icon", "📄"),
            description=data.get("description", ""),
            sub_types=sub_types
        )


class ServiceMasterData:
    """Master data for all services - STATIC DATA (No database needed)"""
    
    # ==================== MASTER SERVICE DATA ====================
    _services: List[ServiceType] = [
        ServiceType(
            id="pan",
            name="PAN Card",
            icon="🪪",
            description="PAN Card related services",
            sub_types=[
                ServiceSubType(
                    id="pan_new",
                    name="New PAN Card Application",
                    description="Apply for a new PAN Card",
                    required_fields=[
                        {"key": "full_name", "label": "Full Name", "type": "text"},
                        {"key": "dob", "label": "Date of Birth", "type": "date"},
                        {"key": "father_name", "label": "Father's Name", "type": "text"},
                    ],
                    required_documents=["Aadhaar Card", "Passport Size Photo"]
                ),
                ServiceSubType(
                    id="pan_update",
                    name="PAN Card Update/Correction",
                    description="Update or correct PAN Card details",
                    required_fields=[
                        {"key": "pan_number", "label": "PAN Number", "type": "text"},
                        {"key": "field_to_update", "label": "Field to Update", "type": "text"},
                    ],
                    required_documents=["Existing PAN Card", "Proof of New Information"]
                ),
            ]
        ),
        ServiceType(
            id="aadhar",
            name="Aadhaar",
            icon="🪪",
            description="Aadhaar related services",
            sub_types=[
                ServiceSubType(
                    id="aadhar_new",
                    name="New Aadhaar Enrollment",
                    description="Apply for new Aadhaar",
                    required_fields=[
                        {"key": "full_name", "label": "Full Name", "type": "text"},
                        {"key": "dob", "label": "Date of Birth", "type": "date"},
                        {"key": "mobile", "label": "Mobile Number", "type": "phone"},
                    ],
                    required_documents=["Birth Certificate", "Identity Proof"]
                ),
                ServiceSubType(
                    id="aadhar_update",
                    name="Aadhaar Update/Correction",
                    description="Update or correct Aadhaar details",
                    required_fields=[
                        {"key": "aadhar_number", "label": "Aadhaar Number", "type": "text"},
                        {"key": "field_to_update", "label": "Field to Update", "type": "text"},
                    ],
                    required_documents=["Aadhaar Card", "Proof of New Information"]
                ),
            ]
        ),
        ServiceType(
            id="epf",
            name="EPF / PF",
            icon="🏦",
            description="EPF (Employees Provident Fund) services",
            sub_types=[
                ServiceSubType(
                    id="pf_withdrawal",
                    name="PF Withdrawal",
                    description="Withdraw PF amount",
                    required_fields=[
                        {"key": "uan_number", "label": "UAN Number", "type": "text"},
                        {"key": "pan_number", "label": "PAN Number", "type": "text"},
                        {"key": "bank_account", "label": "Bank Account Number", "type": "text"},
                    ],
                    required_documents=["UAN Card", "PAN Card", "Bank Account Proof"]
                ),
                ServiceSubType(
                    id="pf_transfer",
                    name="PF Transfer",
                    description="Transfer PF from one company to another",
                    required_fields=[
                        {"key": "uan_number", "label": "UAN Number", "type": "text"},
                        {"key": "previous_employer", "label": "Previous Employer", "type": "text"},
                        {"key": "new_employer", "label": "New Employer", "type": "text"},
                    ],
                    required_documents=["UAN Card", "Previous Employer PF Statement"]
                ),
            ]
        ),
        ServiceType(
            id="passport",
            name="Passport",
            icon="🛂",
            description="Passport related services",
            sub_types=[
                ServiceSubType(
                    id="passport_new",
                    name="New Passport Application",
                    description="Apply for new passport",
                    required_fields=[
                        {"key": "full_name", "label": "Full Name", "type": "text"},
                        {"key": "dob", "label": "Date of Birth", "type": "date"},
                        {"key": "place_of_birth", "label": "Place of Birth", "type": "text"},
                        {"key": "aadhar_number", "label": "Aadhaar Number", "type": "text"},
                    ],
                    required_documents=["Aadhaar Card", "Birth Certificate", "Address Proof"]
                ),
                ServiceSubType(
                    id="passport_renew",
                    name="Passport Renewal",
                    description="Renew expired passport",
                    required_fields=[
                        {"key": "passport_number", "label": "Passport Number", "type": "text"},
                        {"key": "expiry_date", "label": "Expiry Date", "type": "date"},
                    ],
                    required_documents=["Old Passport", "Aadhaar Card"]
                ),
            ]
        ),
        ServiceType(
            id="driving_license",
            name="Driving License",
            icon="🚗",
            description="Driving License services",
            sub_types=[
                ServiceSubType(
                    id="dl_new",
                    name="New Driving License",
                    description="Apply for new driving license",
                    required_fields=[
                        {"key": "full_name", "label": "Full Name", "type": "text"},
                        {"key": "dob", "label": "Date of Birth", "type": "date"},
                        {"key": "aadhar_number", "label": "Aadhaar Number", "type": "text"},
                    ],
                    required_documents=["Aadhaar Card", "Age Proof", "Address Proof"]
                ),
                ServiceSubType(
                    id="dl_renew",
                    name="Driving License Renewal",
                    description="Renew expired driving license",
                    required_fields=[
                        {"key": "license_number", "label": "License Number", "type": "text"},
                        {"key": "expiry_date", "label": "Expiry Date", "type": "date"},
                    ],
                    required_documents=["Old Driving License", "Aadhaar Card"]
                ),
            ]
        ),
        ServiceType(
            id="voter_id",
            name="Voter ID",
            icon="🗳️",
            description="Voter ID services",
            sub_types=[
                ServiceSubType(
                    id="voter_new",
                    name="New Voter ID",
                    description="Apply for new voter ID",
                    required_fields=[
                        {"key": "full_name", "label": "Full Name", "type": "text"},
                        {"key": "dob", "label": "Date of Birth", "type": "date"},
                        {"key": "address", "label": "Address", "type": "text"},
                    ],
                    required_documents=["Aadhaar Card", "Address Proof"]
                ),
                ServiceSubType(
                    id="voter_update",
                    name="Voter ID Update",
                    description="Update voter ID details",
                    required_fields=[
                        {"key": "voter_id", "label": "Voter ID Number", "type": "text"},
                        {"key": "field_to_update", "label": "Field to Update", "type": "text"},
                    ],
                    required_documents=["Voter ID Card", "Proof of New Details"]
                ),
            ]
        ),
        ServiceType(
            id="income_certificate",
            name="Income Certificate",
            icon="💵",
            description="Income Certificate services",
            sub_types=[
                ServiceSubType(
                    id="income_new",
                    name="New Income Certificate",
                    description="Apply for income certificate",
                    required_fields=[
                        {"key": "full_name", "label": "Full Name", "type": "text"},
                        {"key": "annual_income", "label": "Annual Income (₹)", "type": "number"},
                        {"key": "aadhar_number", "label": "Aadhaar Number", "type": "text"},
                    ],
                    required_documents=["Aadhaar Card", "Income Proof", "Address Proof"]
                ),
            ]
        ),
        ServiceType(
            id="caste_certificate",
            name="Caste Certificate",
            icon="📜",
            description="Caste Certificate services",
            sub_types=[
                ServiceSubType(
                    id="caste_new",
                    name="New Caste Certificate",
                    description="Apply for caste certificate",
                    required_fields=[
                        {"key": "full_name", "label": "Full Name", "type": "text"},
                        {"key": "caste", "label": "Caste Category", "type": "dropdown"},
                        {"key": "aadhar_number", "label": "Aadhaar Number", "type": "text"},
                    ],
                    required_documents=["Aadhaar Card", "Address Proof", "Parent's Caste Proof"]
                ),
            ]
        ),
        ServiceType(
            id="domicile",
            name="Domicile Certificate",
            icon="🏠",
            description="Domicile Certificate services",
            sub_types=[
                ServiceSubType(
                    id="domicile_new",
                    name="New Domicile Certificate",
                    description="Apply for domicile certificate",
                    required_fields=[
                        {"key": "full_name", "label": "Full Name", "type": "text"},
                        {"key": "state", "label": "State", "type": "text"},
                        {"key": "aadhar_number", "label": "Aadhaar Number", "type": "text"},
                    ],
                    required_documents=["Aadhaar Card", "Address Proof", "Residence Proof"]
                ),
            ]
        ),
        ServiceType(
            id="disability",
            name="Disability Certificate",
            icon="♿",
            description="Disability Certificate services",
            sub_types=[
                ServiceSubType(
                    id="disability_new",
                    name="New Disability Certificate",
                    description="Apply for disability certificate",
                    required_fields=[
                        {"key": "full_name", "label": "Full Name", "type": "text"},
                        {"key": "disability_type", "label": "Type of Disability", "type": "dropdown"},
                        {"key": "disability_percentage", "label": "Disability Percentage", "type": "number"},
                        {"key": "aadhar_number", "label": "Aadhaar Number", "type": "text"},
                    ],
                    required_documents=["Aadhaar Card", "Medical Certificate", "Doctor's Prescription"]
                ),
            ]
        ),
        ServiceType(
            id="bonafide",
            name="Bonafide Certificate",
            icon="📄",
            description="Bonafide Certificate services",
            sub_types=[
                ServiceSubType(
                    id="bonafide_new",
                    name="New Bonafide Certificate",
                    description="Apply for bonafide certificate",
                    required_fields=[
                        {"key": "full_name", "label": "Full Name", "type": "text"},
                        {"key": "institute", "label": "Institute Name", "type": "text"},
                        {"key": "course", "label": "Course/Class", "type": "text"},
                    ],
                    required_documents=["Student ID Card", "Institute Enrollment Proof"]
                ),
            ]
        ),
        ServiceType(
            id="gap_certificate",
            name="Gap Certificate",
            icon="⏳",
            description="Gap Certificate services",
            sub_types=[
                ServiceSubType(
                    id="gap_new",
                    name="New Gap Certificate",
                    description="Apply for gap certificate",
                    required_fields=[
                        {"key": "full_name", "label": "Full Name", "type": "text"},
                        {"key": "gap_start_date", "label": "Gap Start Date", "type": "date"},
                        {"key": "gap_end_date", "label": "Gap End Date", "type": "date"},
                        {"key": "reason", "label": "Reason for Gap", "type": "text"},
                    ],
                    required_documents=["Aadhaar Card", "Proof of Gap Reason"]
                ),
            ]
        ),
    ]
    
    # ==================== HELPER METHODS ====================
    
    @classmethod
    def get_all_services(cls) -> List[ServiceType]:
        """Get all services"""
        return cls._services
    
    @classmethod
    def get_service_by_id(cls, service_id: str) -> Optional[ServiceType]:
        """Get service by ID"""
        for service in cls._services:
            if service.id == service_id:
                return service
        return None
    
    @classmethod
    def get_sub_type_by_id(cls, sub_type_id: str) -> Optional[ServiceSubType]:
        """Get sub-type by ID"""
        for service in cls._services:
            for sub_type in service.sub_types:
                if sub_type.id == sub_type_id:
                    return sub_type
        return None
    
    @classmethod
    def get_all_service_ids(cls) -> List[str]:
        """Get all service IDs"""
        return [s.id for s in cls._services]
    
    @classmethod
    def get_all_sub_type_ids(cls) -> List[str]:
        """Get all sub-type IDs"""
        ids = []
        for service in cls._services:
            for sub_type in service.sub_types:
                ids.append(sub_type.id)
        return ids
    
    @classmethod
    def get_service_by_sub_type(cls, sub_type_id: str) -> Optional[ServiceType]:
        """Get service that contains the given sub-type"""
        for service in cls._services:
            for sub_type in service.sub_types:
                if sub_type.id == sub_type_id:
                    return service
        return None
    
    @classmethod
    def get_services_with_sub_types(cls) -> List[ServiceType]:
        """Get services that have at least one sub-type"""
        return [s for s in cls._services if s.sub_types]
    
    @classmethod
    def to_json(cls) -> List[Dict]:
        """Convert all services to JSON"""
        return [s.to_dict() for s in cls._services]