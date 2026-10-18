# app/modules/jobs/job_fetch.py - COMPLETE UPDATED VERSION WITH JOB_LOCATION SUPPORT

from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
import httpx
import logging
from datetime import datetime, timedelta
from tenacity import retry, stop_after_attempt, wait_fixed
import asyncio
from bs4 import BeautifulSoup
import re
import os
from typing import Tuple, List, Dict, Any
from dotenv import load_dotenv
from urllib.parse import quote, unquote, urlparse

from app.db.connection import get_db

# Load environment variables
load_dotenv()

# Logger configuration
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
router = APIRouter()

# Cache for organization search results
organization_cache = {}

# Default email for added_by field
default_email = "yhk.capital@gmail.com"


# ==================== HELPER FUNCTIONS ====================

def safe_string(value, default=""):
    """Safely convert any value to string"""
    if value is None:
        return default
    if isinstance(value, list):
        # Pythonic way: check if list has items (equivalent to isNotEmpty)
        return ", ".join([str(v) for v in value]) if value else default
    if isinstance(value, dict):
        return str(value) if value else default
    return str(value)


def safe_category(category):
    """Safely handle category field"""
    if category is None:
        return "General"
    if isinstance(category, list):
        # Pythonic way: check if list has items
        return ", ".join(category) if category else "General"
    if isinstance(category, dict):
        return category.get("tag", category.get("name", "General"))
    return str(category)


def safe_location(location):
    """Safely handle location field"""
    if location is None:
        return "India"
    if isinstance(location, dict):
        return location.get("display_name", location.get("name", "India"))
    if isinstance(location, list):
        # Pythonic way: check if list has items
        return ", ".join(location) if location else "India"
    return str(location)


def get_short_location_name(location_name: str) -> str:
    """Get short location name (City, State only)"""
    # Pythonic way: check if string has content (equivalent to isNotEmpty)
    if not location_name:
        return "India"
    
    # Split by comma and take first 2-3 parts
    parts = [p.strip() for p in location_name.split(',')]
    
    # If we have city and state, return "City, State"
    if len(parts) >= 2:
        city = parts[0]
        state = parts[1]
        # Remove country if present
        if len(parts) > 2 and parts[2] == "India":
            return f"{city}, {state}"
        return f"{city}, {state}"
    # Pythonic way: check if list has items
    elif parts:
        return parts[0]
    else:
        return location_name[:50]


def clean_organization_name(organization: str, job_title: str = "", description: str = "") -> str:
    """Clean and extract company name from organization"""
    try:
        organization = organization.strip().lower()
        # Pythonic way: check if string has content
        if not organization or organization == "n/a":
            for source in [job_title, description]:
                if source:
                    matches = re.findall(r'\b[A-Z][a-zA-Z0-9&\- ]+[a-zA-Z0-9]\b', source)
                    for match in matches:
                        if len(match) > 3 and not re.search(r'\b(job|role|position|team|work)\b', match, re.IGNORECASE):
                            return match.strip().capitalize()
            raise ValueError("No valid organization name found")

        noise_terms = [
            r"client of", r"private limited", r"pvt\.? ltd\.?", r"ltd\.?", r"limited",
            r"inc\.?", r"corp\.?", r"corporation", r"llp", r"llc", r"& co\.?"
        ]
        cleaned_name = organization
        for term in noise_terms:
            cleaned_name = re.sub(term, "", cleaned_name, flags=re.IGNORECASE).strip()

        # Pythonic way: check if string has content
        if cleaned_name and len(cleaned_name) > 3:
            return cleaned_name.capitalize()
        raise ValueError(f"Invalid organization name after cleaning: {cleaned_name}")
    except Exception as e:
        logger.error(f"Error cleaning organization name '{organization}': {str(e)}")
        raise ValueError(f"Invalid organization name: {str(e)}")


async def google_search(query: str, max_results: int = 1) -> list[dict]:
    """Google search function"""
    encoded_query = quote(query)
    url = f"https://www.google.com/search?q={encoded_query}&num={max_results}"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, headers=headers)
            response.raise_for_status()
        soup = BeautifulSoup(response.text, "html.parser")
        results = []
        for g in soup.find_all("div", class_="g")[:max_results]:
            a = g.find("a", href=True)
            if a:
                href = a["href"]
                if "/url?q=" in href and "&sa=" in href:
                    m = re.search(r'/url\?q=(.*?)&', href)
                    if m:
                        actual_url = unquote(m.group(1))
                        if actual_url.startswith("http"):
                            results.append({"href": actual_url})
                elif href.startswith("http"):
                    results.append({"href": href})
        return results
    except Exception as e:
        logger.error(f"Google search failed for query '{query}': {e}")
        return []


async def find_career_page(organization: str, job_title: str = "", description: str = "") -> tuple[str, str]:
    """Find career page for organization"""
    global organization_cache
    cache_key = None
    try:
        search_name = clean_organization_name(organization, job_title, description)
        cache_key = search_name.lower()
        if cache_key in organization_cache:
            return organization_cache[cache_key]

        website_results = await google_search(f'"{search_name}"', max_results=1)
        # Pythonic way: check if list has items
        if not website_results or not website_results[0].get("href"):
            google_url = f"https://www.google.com/search?q={quote(search_name)}"
            organization_cache[cache_key] = (google_url, google_url)
            return google_url, google_url

        website_url = website_results[0]["href"]
        domain = urlparse(website_url).netloc.replace("www.", "")
        career_keywords_query = f'"{search_name}" (careers OR jobs OR vacancies) site:{domain}'
        career_results = await google_search(career_keywords_query, max_results=1)
        # Pythonic way: check if list has items
        career_url = career_results[0]["href"] if career_results and career_results[0].get("href") else website_url
        organization_cache[cache_key] = (website_url, career_url)
        return website_url, career_url
    except Exception as e:
        logger.error(f"Error finding website for {organization}: {str(e)}")
        fallback_query = quote(organization.replace(' ', '+'))
        google_url = f"https://www.google.com/search?q={fallback_query}"
        if cache_key:
            organization_cache[cache_key] = (google_url, google_url)
        return google_url, google_url
    finally:
        await asyncio.sleep(1)


async def geocode_location_async(location_text: str) -> Dict[str, Any]:
    """Geocode location to get coordinates and short name"""
    # Pythonic way: check if string has content
    if not location_text or location_text.lower() in ["n/a", "remote", "", "anywhere"]:
        return {
            "latitude": 0.0,
            "longitude": 0.0,
            "location_name": "Remote",
            "short_location": "Remote",
            "city": None,
            "state": None,
            "country": "India",
            "is_geocoded": False
        }
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                "https://nominatim.openstreetmap.org/search",
                params={
                    "q": location_text,
                    "format": "json",
                    "limit": 1
                },
                headers={"User-Agent": "rojgarnest/1.0"}
            )
            
            if response.status_code == 200:
                data = response.json()
                # Pythonic way: check if list has items
                if data:
                    address = data[0].get("address", {})
                    city = address.get("city") or address.get("town") or address.get("village") or ""
                    state = address.get("state") or ""
                    country = address.get("country") or "India"
                    
                    # Create short location name
                    # Pythonic way: check if strings have content
                    if city and state:
                        short_location = f"{city}, {state}"
                    elif city:
                        short_location = city
                    elif state:
                        short_location = state
                    else:
                        short_location = get_short_location_name(data[0].get("display_name", location_text))
                    
                    return {
                        "latitude": float(data[0]["lat"]),
                        "longitude": float(data[0]["lon"]),
                        "location_name": get_short_location_name(data[0].get("display_name", location_text)),
                        "short_location": short_location,
                        "city": city,
                        "state": state,
                        "country": country,
                        "is_geocoded": True
                    }
    except Exception as e:
        logger.error(f"Geocoding failed for '{location_text}': {e}")
    
    # Fallback
    return {
        "latitude": 0.0,
        "longitude": 0.0,
        "location_name": get_short_location_name(location_text),
        "short_location": get_short_location_name(location_text),
        "city": None,
        "state": None,
        "country": "India",
        "is_geocoded": False
    }


# ==================== SIMPLE VALIDATION ====================

def is_valid_job(job_data: Dict) -> Tuple[bool, str]:
    """
    Simple validation - checks if job should be inserted
    Returns: (is_valid, reason)
    """
    # Check required fields
    if not job_data.get("post_name") or len(job_data.get("post_name", "")) < 3:
        return False, "Invalid job title"
    
    if not job_data.get("organization") or len(job_data.get("organization", "")) < 2:
        return False, "Invalid company name"
    
    if not job_data.get("description") or len(job_data.get("description", "")) < 50:
        return False, "Description too short"
    
    # Check for spam/scam keywords
    scam_keywords = ['investment', 'deposit', 'fee', 'crypto', 'bitcoin', 'forex', 'work from home']
    description_lower = job_data.get("description", "").lower()
    title_lower = job_data.get("post_name", "").lower()
    
    for keyword in scam_keywords:
        if keyword in description_lower or keyword in title_lower:
            return False, f"Contains suspicious keyword: {keyword}"
    
    return True, "Valid job"


# ==================== SAVE JOBS TO DATABASE (With job_location) ====================

async def save_jobs_to_db(jobs):
    """Save jobs to MongoDB with job_location field"""
    try:
        db = get_db()
        if db is None:
            logger.error("Database connection is None")
            return 0, 0, len(jobs)

        jobs_collection = db.job
        inserted = 0
        updated = 0
        skipped = 0

        for job_data in jobs:
            try:
                # Simple validation
                is_valid, reason = is_valid_job(job_data)
                
                if not is_valid:
                    logger.warning(f"Skipping invalid job: {job_data.get('post_name', 'Unknown')} - {reason}")
                    skipped += 1
                    continue

                # Remove _id if present
                if "_id" in job_data:
                    del job_data["_id"]

                # Apply safe conversions
                job_data["category"] = safe_category(job_data.get("category"))
                
                # Handle location with geocoding
                location_text = safe_location(job_data.get("location"))
                
                # Geocode to get coordinates and short location name
                geocode_result = await geocode_location_async(location_text)
                
                # Set job_location field
                job_data["job_location"] = {
                    "latitude": geocode_result["latitude"],
                    "longitude": geocode_result["longitude"],
                    "location_name": geocode_result["short_location"],  # Short name for display
                    "city": geocode_result.get("city"),
                    "state": geocode_result.get("state"),
                    "country": geocode_result.get("country", "India"),
                    "is_geocoded": geocode_result["is_geocoded"],
                    "geocoded_at": datetime.utcnow() if geocode_result["is_geocoded"] else None
                }
                
                # Also keep original location field for backward compatibility
                job_data["location"] = geocode_result["short_location"] or location_text

                # Set defaults
                job_data["added_by"] = default_email
                job_data["created_at"] = job_data.get("created_at", datetime.utcnow())
                job_data["updated_at"] = datetime.utcnow()
                job_data["status"] = "open"
                job_data["salary_currency"] = "INR"
                job_data["job_level"] = "mid"
                job_data["experience_min_years"] = 0
                job_data["required_skills"] = job_data.get("required_skills", [])
                job_data["nice_to_have_skills"] = job_data.get("nice_to_have_skills", [])
                job_data["benefits"] = job_data.get("benefits", [])
                job_data["tags"] = job_data.get("tags", [])

                # Ensure string fields - using Pythonic truthiness checks
                string_fields = ["post_name", "organization", "job_type", "description", "qualification"]
                for field in string_fields:
                    if field in job_data and isinstance(job_data[field], list):
                        # Pythonic way: check if list has items
                        job_data[field] = ", ".join(job_data[field]) if job_data[field] else "N/A"
                    elif field in job_data and job_data[field] is None:
                        job_data[field] = "N/A"
                    elif field not in job_data:
                        job_data[field] = "N/A"

                # Validate job_type
                if job_data.get("job_type") not in ["private", "remote", "government", "hybrid"]:
                    job_data["job_type"] = "private"

                # Check if job already exists
                existing = await jobs_collection.find_one({
                    "post_name": job_data.get("post_name"),
                    "organization": job_data.get("organization")
                })

                if existing:
                    # Update existing job
                    await jobs_collection.update_one(
                        {"_id": existing["_id"]},
                        {"$set": job_data}
                    )
                    updated += 1
                    logger.debug(f"Updated job: {job_data.get('post_name')}")
                else:
                    # Insert new job
                    await jobs_collection.insert_one(job_data)
                    inserted += 1
                    logger.debug(f"Inserted job: {job_data.get('post_name')}")

            except Exception as e:
                logger.error(f"Error processing job {job_data.get('post_name', 'Unknown')}: {str(e)}")
                skipped += 1
                continue

        logger.info(f"Saved {inserted} new jobs, updated {updated} existing jobs, skipped {skipped} jobs")
        return inserted, updated, skipped

    except Exception as e:
        logger.error(f"Unexpected error saving jobs: {str(e)}")
        return 0, 0, len(jobs)


# ==================== FETCH JOBS FROM APIS ====================

@retry(stop=stop_after_attempt(2), wait=wait_fixed(2))
async def fetch_adzuna_jobs():
    """Fetch private jobs from Adzuna API"""
    private_jobs = []
    try:
        adzuna_app_id = os.getenv("ADZUNA_APP_ID")
        adzuna_api_key = os.getenv("ADZUNA_API_KEY")

        if not adzuna_app_id or not adzuna_api_key:
            logger.debug("Adzuna API credentials not configured")
            return private_jobs

        async with httpx.AsyncClient(timeout=15.0) as client:
            params = {
                "app_id": adzuna_app_id,
                "app_key": adzuna_api_key,
                "results_per_page": 10,
                "what": "software engineer",
                "where": "India",
                "sort_by": "date",
            }
            response = await client.get("https://api.adzuna.com/v1/api/jobs/in/search/1", params=params)
            
            if response.status_code == 200:
                adzuna_data = response.json().get("results", [])
                
                for job in adzuna_data[:15]:
                    try:
                        job_title = job.get("title", "")
                        if not job_title:
                            continue
                            
                        company = job.get("company", {})
                        organization = company.get("display_name", "Unknown Company")
                        
                        location = job.get("location", {})
                        location_name = location.get("display_name", "India")
                        
                        description = job.get("description", "No description available")
                        soup = BeautifulSoup(description, "html.parser")
                        cleaned_description = soup.get_text()[:1000]
                        
                        job_data = {
                            "post_date": datetime.utcnow().strftime("%Y-%m-%d"),
                            "organization": organization,
                            "location": location_name,
                            "post_name": job_title[:200],
                            "job_type": "private",
                            "description": cleaned_description,
                            "category": "IT/Software",
                            "status": "open",
                            "website_url": company.get("url", "#"),
                            "action": job.get("redirect_url", "#"),
                            "source": "adzuna"
                        }
                        private_jobs.append(job_data)
                        
                    except Exception as e:
                        logger.debug(f"Skipping Adzuna job: {e}")
                        continue

        logger.info(f"Fetched {len(private_jobs)} jobs from Adzuna")
        return private_jobs

    except Exception as e:
        logger.error(f"Error fetching Adzuna jobs: {e}")
        return []


@retry(stop=stop_after_attempt(2), wait=wait_fixed(2))
async def fetch_remotive_jobs():
    """Fetch remote jobs from Remotive API"""
    remote_jobs = []
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get("https://remotive.com/api/remote-jobs", params={"limit": 15})
            
            if response.status_code == 200:
                remotive_data = response.json().get("jobs", [])
                
                for job in remotive_data[:15]:
                    try:
                        job_title = job.get("title", "")
                        if not job_title:
                            continue
                            
                        organization = job.get("company_name", "Unknown Company")
                        location = job.get("candidate_required_location", "Remote")
                        description = job.get("description", "No description available")
                        
                        soup = BeautifulSoup(description, "html.parser")
                        cleaned_description = soup.get_text()[:1000]
                        
                        job_data = {
                            "post_date": job.get("publication_date", datetime.utcnow().strftime("%Y-%m-%d")).split("T")[0],
                            "organization": organization,
                            "location": location,
                            "post_name": job_title[:200],
                            "job_type": "remote",
                            "description": cleaned_description,
                            "category": job.get("category", "Remote Work"),
                            "status": "open",
                            "website_url": job.get("url", "#"),
                            "action": job.get("url", "#"),
                            "source": "remotive"
                        }
                        remote_jobs.append(job_data)
                        
                    except Exception as e:
                        logger.debug(f"Skipping Remotive job: {e}")
                        continue

        logger.info(f"Fetched {len(remote_jobs)} jobs from Remotive")
        return remote_jobs

    except Exception as e:
        logger.error(f"Error fetching Remotive jobs: {e}")
        return []


async def fetch_jobicy_jobs():
    """Fetch remote jobs from Jobicy API"""
    remote_jobs = []
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get("https://jobicy.com/api/v2/remote-jobs", params={"count": 15})
            
            if response.status_code == 200:
                jobicy_data = response.json().get("jobs", [])
                
                for job in jobicy_data[:15]:
                    try:
                        job_title = job.get("jobTitle", "")
                        if not job_title:
                            continue
                            
                        organization = job.get("company", "Unknown Company")
                        location = job.get("geo", "Remote")
                        description = job.get("jobDesc", "No description available")
                        
                        soup = BeautifulSoup(description, "html.parser")
                        cleaned_description = soup.get_text()[:1000]
                        
                        job_data = {
                            "post_date": job.get("pubDate", datetime.utcnow().strftime("%Y-%m-%d")).split("T")[0],
                            "organization": organization,
                            "location": location,
                            "post_name": job_title[:200],
                            "job_type": "remote",
                            "description": cleaned_description,
                            "category": job.get("jobType", "Remote Work"),
                            "status": "open",
                            "website_url": job.get("url", "#"),
                            "action": job.get("url", "#"),
                            "source": "jobicy"
                        }
                        remote_jobs.append(job_data)
                        
                    except Exception as e:
                        logger.debug(f"Skipping Jobicy job: {e}")
                        continue

        logger.info(f"Fetched {len(remote_jobs)} jobs from Jobicy")
        return remote_jobs

    except Exception as e:
        logger.error(f"Error fetching Jobicy jobs: {e}")
        return []


# ==================== MAIN FETCH FUNCTION ====================

@router.get("/fetch-jobs", response_class=JSONResponse)
async def fetch_and_save_jobs():
    """Endpoint to fetch and save jobs to MongoDB"""
    try:
        logger.info("Starting job fetch and save process")

        results = await asyncio.gather(
            fetch_adzuna_jobs(),
            fetch_remotive_jobs(),
            fetch_jobicy_jobs(),
            return_exceptions=True
        )

        all_jobs = []
        sources = ["Adzuna", "Remotive", "Jobicy"]

        for i, (jobs_result, source) in enumerate(zip(results, sources)):
            if isinstance(jobs_result, list):
                all_jobs.extend(jobs_result)
                logger.info(f"Added {len(jobs_result)} jobs from {source}")
            else:
                logger.warning(f"{source} jobs fetch failed: {str(jobs_result)}")

        logger.info(f"Total jobs to process: {len(all_jobs)}")

        if all_jobs:
            inserted, updated, skipped = await save_jobs_to_db(all_jobs)
            return JSONResponse(
                status_code=200,
                content={
                    "success": True,
                    "message": f"Successfully processed {len(all_jobs)} jobs",
                    "jobs_fetched": len(all_jobs),
                    "jobs_inserted": inserted,
                    "jobs_updated": updated,
                    "jobs_skipped": skipped
                }
            )
        else:
            return JSONResponse(
                status_code=200,
                content={
                    "success": True,
                    "message": "No jobs fetched from any source",
                    "jobs_fetched": 0,
                    "jobs_inserted": 0,
                    "jobs_updated": 0,
                    "jobs_skipped": 0
                }
            )

    except Exception as e:
        logger.error(f"Error in fetch_and_save_jobs: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "message": f"Failed to fetch and save jobs: {str(e)}",
                "jobs_fetched": 0,
                "jobs_inserted": 0,
                "jobs_updated": 0,
                "jobs_skipped": 0
            }
        )


# ==================== HEALTH CHECK ====================

@router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "module": "job_fetch",
        "collections_used": ["job"],
        "apis": ["Adzuna", "Remotive", "Jobicy"]
    }


print("✅ Job Fetch Module Loaded (With job_location and short location names)")