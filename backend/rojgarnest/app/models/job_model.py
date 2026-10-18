# app/models/job_model.py - COMPLETE FIXED VERSION WITH ALL CLASSES + color_type
# ✅ NEW: color_type field added with 12-color validation

from pydantic import BaseModel, Field, field_validator, model_validator
from typing import List, Optional, Dict, Any
from datetime import datetime
from bs4 import BeautifulSoup
import httpx
from app.core.utils.logger import logger

# ==================== JOB LOCATION MODEL ====================
class JobLocation(BaseModel):
    latitude: float = Field(default=0.0, ge=-90, le=90)
    longitude: float = Field(default=0.0, ge=-180, le=180)
    location_name: str = Field(default="")
    city: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    country: str = "India"
    is_geocoded: bool = False
    geocoded_at: Optional[datetime] = None
    source: str = Field(default="manual")


# ==================== JOB ATTACHMENT MODEL ====================
class JobAttachment(BaseModel):
    type: str = Field(..., pattern="^(pdf|image|doc|notice|brochure|logo)$")
    name: str
    url: str
    size_kb: Optional[int] = None
    uploaded_at: datetime = Field(default_factory=datetime.utcnow)


# ==================== INDIVIDUAL POST MODEL ====================
class IndividualPost(BaseModel):
    """Individual post model for backward compatibility"""
    post_name: str
    total_posts: int = Field(default=1, ge=1)
    age_min: Optional[int] = None
    age_max: Optional[int] = None
    qualification: Optional[str] = None
    pay_scale: Optional[str] = None
    reservation: Optional[str] = None


# ==================== PAY SCALE MODEL ====================
class PayScale(BaseModel):
    pay_scale: Optional[str] = Field(default=None, description="Pay scale e.g., ₹44,900 - ₹1,42,400")
    grade_pay: Optional[str] = Field(default=None, description="Grade pay amount")
    pay_band: Optional[str] = Field(default=None, description="Pay band level")
    min_salary: Optional[int] = Field(default=None, description="Minimum salary in rupees")
    max_salary: Optional[int] = Field(default=None, description="Maximum salary in rupees")

    @model_validator(mode='after')
    def clean_empty_pay_scale(self):
        if self.pay_scale is None:
            self.pay_scale = ""
        return self


# ==================== CATEGORY VACANCY MODEL ====================
class CategoryVacancy(BaseModel):
    name: str
    vacancy: int


# ==================== MULTIPLE POST MODEL ====================
class MultiplePost(BaseModel):
    post_name: str
    total_posts: int = Field(ge=1)
    qualification: str
    qualification_main: Optional[str] = None
    qualification_sub: Optional[str] = None
    degree_stream: Optional[str] = None
    degree_name: Optional[str] = None
    age_min: Optional[int] = None
    age_max: Optional[int] = None
    experience_details: Optional[str] = Field(default=None, description="Experience required for this post")
    pay_scales: List[PayScale] = Field(default_factory=list)
    category_vacancies: List[CategoryVacancy] = Field(default_factory=list)


# ==================== AGE LIMIT MODEL ====================
class AgeLimit(BaseModel):
    min_years: Optional[int] = None
    max_years: Optional[int] = None
    as_on_date: Optional[str] = None
    relaxation_details: Optional[str] = None


# ==================== PHYSICAL ELIGIBILITY MODEL ====================
class PhysicalEligibility(BaseModel):
    min_height_cm: Optional[str] = None
    min_height_female_cm: Optional[str] = None
    min_chest_cm: Optional[str] = None
    max_weight_kg: Optional[str] = None
    relaxation: Optional[str] = None


# ==================== TRAINING DETAILS MODEL ====================
class TrainingDetails(BaseModel):
    duration: Optional[str] = None
    stipend: Optional[int] = None
    location: Optional[str] = None


# ==================== REQUIRED SKILL MODEL ====================
class RequiredSkill(BaseModel):
    name: str
    min_proficiency: str = Field(..., pattern="^(beginner|intermediate|advanced|expert)$")
    importance: int = Field(default=5, ge=1, le=10)


# ==================== NICE TO HAVE SKILL MODEL ====================
class NiceToHaveSkill(BaseModel):
    name: str
    importance: int = Field(default=5, ge=1, le=10)


# ==================== GEOCODING HELPERS ====================
async def geocode_location_async(location_text: str) -> Dict[str, Any]:
    """Convert address to coordinates using OpenStreetMap (FREE)"""
    if not location_text or location_text.lower() in ["n/a", "remote", "", "anywhere"]:
        return {
            "latitude": 0.0,
            "longitude": 0.0,
            "location_name": location_text if location_text else "Remote",
            "city": None,
            "district": None,
            "state": None,
            "country": "India",
            "is_geocoded": False,
            "geocoded_at": None,
            "source": "manual"
        }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                "https://nominatim.openstreetmap.org/search",
                params={
                    "q": location_text,
                    "format": "json",
                    "limit": 1,
                    "addressdetails": 1
                },
                headers={"User-Agent": "rojgarnest/1.0"}
            )

            if response.status_code == 200:
                data = response.json()
                if data and len(data) > 0:
                    address = data[0].get("address", {})
                    city = address.get("city") or address.get("town") or address.get("village") or ""
                    district = address.get("state_district") or address.get("county") or ""
                    state = address.get("state") or ""

                    location_parts = []
                    if city:
                        location_parts.append(city)
                    if state and state != city:
                        location_parts.append(state)
                    location_name = ", ".join(location_parts) if location_parts else data[0].get("display_name", location_text)

                    return {
                        "latitude": float(data[0]["lat"]),
                        "longitude": float(data[0]["lon"]),
                        "location_name": location_name,
                        "city": city,
                        "district": district,
                        "state": state,
                        "country": "India",
                        "is_geocoded": True,
                        "geocoded_at": datetime.utcnow(),
                        "source": "geocoded"
                    }
    except Exception as e:
        logger.error(f"Geocoding failed for '{location_text}': {e}")

    return {
        "latitude": 0.0,
        "longitude": 0.0,
        "location_name": location_text if location_text else "India",
        "city": None,
        "district": None,
        "state": None,
        "country": "India",
        "is_geocoded": False,
        "geocoded_at": None,
        "source": "manual"
    }


async def get_admin_current_location(admin_email: str, db) -> Optional[Dict[str, Any]]:
    """Fetch admin's current location from auth table"""
    try:
        admin = await db.auth.find_one({"email": admin_email})
        if admin and admin.get("current_location"):
            loc = admin["current_location"]
            location_name = loc.get("location_name", "")
            city = loc.get("city")
            state = loc.get("state")

            if not location_name and city and state:
                location_name = f"{city}, {state}"
            elif not location_name and city:
                location_name = city

            return {
                "latitude": loc.get("latitude", 0.0),
                "longitude": loc.get("longitude", 0.0),
                "location_name": location_name,
                "city": loc.get("city"),
                "district": loc.get("district"),
                "state": loc.get("state"),
                "country": loc.get("country", "India"),
                "is_geocoded": True,
                "geocoded_at": datetime.utcnow(),
                "source": "current_location"
            }
        return None
    except Exception as e:
        logger.error(f"Failed to fetch admin location for {admin_email}: {e}")
        return None


# ==================== MAIN JOB MODEL ====================
class JobModel(BaseModel):
    # Basic Info
    post_date: str
    organization: str
    post_name: str
    location_text: str = Field(default="")
    use_current_location: bool = False
    job_location: JobLocation = Field(default_factory=JobLocation)

    # Job Type & Category
    job_type: str = Field(default="private", pattern="^(private|remote|government|hybrid)$")
    job_level: str = Field(default="mid", pattern="^(entry|mid|senior|lead|executive)$")
    category: str = Field(default="IT")

    # ==================== ✅ NEW: COLOR TYPE ====================
    color_type: str = Field(
        default="blue",
        pattern="^(blue|green|red|orange|purple|teal|pink|indigo|amber|cyan|grey|gray|white)$",
        description="Visual color theme for this job (used for filtering & UI)"
    )

    # Status
    status: str = Field(default="open", pattern="^(open|closed|filled)$")

    # Qualification
    required_qualification: str = Field(default="Any Graduate")

    # Experience
    experience_min_years: int = Field(default=0, ge=0)
    experience_max_years: Optional[int] = None

    # Skills
    required_skills: List[RequiredSkill] = Field(default_factory=list)
    nice_to_have_skills: List[NiceToHaveSkill] = Field(default_factory=list)
    benefits: List[str] = Field(default_factory=list)
    tags: List[str] = Field(default_factory=list)

    # Content
    description: Optional[str] = None
    last_date: Optional[str] = None
    action: str = "#"
    website_url: str = "#"

    # Apply with Us Link
    apply_with_us_url: Optional[str] = None
    has_apply_with_us: bool = False

    # Official Notification PDF Link
    official_notification_url: Optional[str] = None
    has_official_notification: bool = False

    # Advertisement File Upload
    advertisement_url: Optional[str] = None
    advertisement_download_url: Optional[str] = None
    advertisement_name: Optional[str] = None
    advertisement_storage: Optional[str] = None
    advertisement_public_id: Optional[str] = None
    advertisement_resource_type: Optional[str] = None
    advertisement_is_public: bool = False
    advertisement_is_pdf: bool = False
    advertisement_folder_path: Optional[str] = None
    advertisement_file_size: Optional[int] = None

    # File Attachments
    attachments: List[JobAttachment] = Field(default_factory=list)

    # Age Limit
    age_min_years: Optional[int] = None
    age_max_years: Optional[int] = None
    age_calculation_date: Optional[str] = None
    age_relaxation_details: Optional[str] = None
    age_relaxation_by_category: Optional[Dict[str, int]] = None

    # Multi-Post Support
    total_posts: Optional[int] = None
    multiple_posts: List[MultiplePost] = Field(default_factory=list)

    # Physical Eligibility
    physical_eligibility: Optional[PhysicalEligibility] = None

    # Medical Standards
    medical_standards: Optional[str] = None

    # Training Details
    training_details: Optional[TrainingDetails] = None

    # Bond
    has_bond: bool = False
    bond_duration: Optional[str] = None
    bond_amount: Optional[int] = None
    bond_terms: Optional[str] = None

    # Education Details
    education_details: Optional[str] = None
    experience_details: Optional[str] = None
    is_fresher_eligible: bool = True
    is_experienced_eligible: bool = True

    # Work Details
    work_schedule: str = Field(default="Full Time")
    shift: str = Field(default="Day Shift")
    working_days: str = Field(default="Monday to Friday")

    # Languages
    languages_required: List[str] = Field(default_factory=list)
    other_languages: Optional[str] = None

    # Interview Details
    interview_venue: Optional[str] = None
    interview_link: Optional[str] = None
    interview_date: Optional[str] = None
    interview_time: Optional[str] = None
    interview_documents: List[str] = Field(default_factory=list)

    # Contact Information
    contact_person: Optional[str] = None
    contact_designation: Optional[str] = None
    contact_email: Optional[str] = None
    contact_phone: Optional[str] = None
    important_notes: Optional[str] = None
    terms_conditions: Optional[str] = None

    # Selection Process
    selection_stages: List[str] = Field(default_factory=list)
    selection_process_details: Optional[str] = None

    # Urgency & Gender
    urgency_level: str = Field(default="Normal")
    gender_preference: str = Field(default="Any")

    # Remote/Hybrid
    is_fully_remote: bool = False
    is_hybrid: bool = False

    # Official Website
    official_website: Optional[str] = None

    # Helpline
    helpline_number: Optional[str] = None
    helpline_email: Optional[str] = None

    # WhatsApp & Telegram
    whatsapp_number: Optional[str] = None
    telegram_channel: Optional[str] = None

    # Application Mode
    application_mode: str = Field(default="Online")

    # Exam Cities
    exam_cities: List[str] = Field(default_factory=list)

    # Important Dates
    application_start_date: Optional[str] = None
    application_end_date: Optional[str] = None
    admit_card_date: Optional[str] = None
    exam_date: Optional[str] = None
    result_date: Optional[str] = None

    # Application Fees
    has_application_fees: bool = Field(default=False)
    application_fees: Optional[Dict[str, int]] = Field(
        default_factory=dict,
        description="Category-wise application fees e.g., {'general/ur': 500, 'obc': 300}"
    )

    # Metadata
    added_by: str
    source: str = "manual"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    views_count: int = 0
    applications_count: int = 0

    # ==================== VALIDATORS ====================
    @field_validator('organization', 'post_name')
    @classmethod
    def validate_not_empty(cls, v: str) -> str:
        if not v or str(v).strip() in ["", "N/A", "n/a"]:
            raise ValueError("Field cannot be empty")
        return str(v).strip()

    @field_validator('description', mode='before')
    @classmethod
    def clean_description(cls, v: Any) -> str:
        if not v:
            return ""
        try:
            soup = BeautifulSoup(str(v), "html.parser")
            for script in soup(["script", "style"]):
                script.decompose()
            return " ".join(soup.get_text().split())
        except Exception:
            return str(v)[:5000]

    @model_validator(mode='before')
    @classmethod
    def set_defaults(cls, values: Dict[str, Any]) -> Dict[str, Any]:
        if not values.get('post_date'):
            values['post_date'] = datetime.utcnow().strftime("%Y-%m-%d")

        # ✅ Color type normalization
        if 'color_type' not in values or not values.get('color_type'):
            values['color_type'] = 'blue'
        else:
            ct = str(values['color_type']).lower().strip()
            if ct == 'gray':
                ct = 'grey'
            values['color_type'] = ct

        apply_url = values.get('apply_with_us_url')
        if apply_url and str(apply_url).strip() and str(apply_url).strip() != '#':
            values['has_apply_with_us'] = True

        official_url = values.get('official_notification_url')
        if official_url and str(official_url).strip() and str(official_url).strip() != '#':
            values['has_official_notification'] = True

        application_fees = values.get('application_fees')
        if application_fees and isinstance(application_fees, dict) and len(application_fees) > 0:
            valid_fees = {k: v for k, v in application_fees.items() if v and int(v) > 0}
            if valid_fees:
                values['application_fees'] = valid_fees
                values['has_application_fees'] = True
            else:
                values['has_application_fees'] = False
        else:
            values['has_application_fees'] = False

        if values.get('use_current_location') and not values.get('location_text'):
            values['location_text'] = "Current Location (will be replaced)"

        return values

    class Config:
        collection = "job"
        arbitrary_types_allowed = True
        populate_by_name = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


print("✅ Job Model Loaded Successfully")
print("   ✅ NEW: color_type field added (12 colors supported)")
print("   Exported: JobModel, JobLocation, JobAttachment, IndividualPost, MultiplePost, PayScale, CategoryVacancy")