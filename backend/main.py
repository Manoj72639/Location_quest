import math
import firebase_admin
from firebase_admin import auth, firestore
from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

if not firebase_admin._apps:
    firebase_admin.initialize_app()

db = firestore.client()
app = FastAPI(title="Location Quest API", version="1.0.0")

class ValidateRequest(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    accuracy: float = Field(ge=0, le=10000)

def get_uid(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Firebase ID token.")
    token = authorization.removeprefix("Bearer ").strip()
    try:
        return auth.verify_id_token(token, check_revoked=True)["uid"]
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired Firebase ID token.")

def distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Haversine great-circle distance in metres."""
    earth_radius = 6_371_000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    a = max(0.0, min(1.0, a))
    return earth_radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/quests")
def list_quests(uid: str = Depends(get_uid)):
    docs = db.collection("quests").where("isActive", "==", True).stream()
    return [{"id": doc.id, **doc.to_dict()} for doc in docs]

@app.post("/quests/{quest_id}/validate")
def validate_quest(quest_id: str, payload: ValidateRequest, uid: str = Depends(get_uid)):
    if payload.accuracy > 50:
        raise HTTPException(status_code=400, detail="GPS accuracy is too low. Try outdoors.")

    quest_ref = db.collection("quests").document(quest_id)
    user_ref = db.collection("users").document(uid)
    completion_ref = user_ref.collection("completions").document(quest_id)

    @firestore.transactional
    def apply_reward(tx):
        quest_snap = quest_ref.get(transaction=tx)
        if not quest_snap.exists:
            raise HTTPException(status_code=404, detail="Quest not found.")
        quest = quest_snap.to_dict() or {}
        if not quest.get("isActive", True):
            raise HTTPException(status_code=400, detail="Quest is not active.")
        try:
            qlat = float(quest["latitude"])
            qlon = float(quest["longitude"])
            radius = float(quest.get("radiusMeters", 50))
            reward = int(quest.get("xpReward", 100))
        except (KeyError, TypeError, ValueError):
            raise HTTPException(status_code=500, detail="Invalid quest configuration.")
        if not all(math.isfinite(v) for v in (qlat, qlon, radius)):
            raise HTTPException(status_code=500, detail="Invalid quest configuration.")
        if not (-90 <= qlat <= 90 and -180 <= qlon <= 180):
            raise HTTPException(status_code=500, detail="Invalid quest coordinates.")
        if radius <= 0 or reward < 0:
            raise HTTPException(status_code=500, detail="Invalid quest radius or reward.")

        distance = distance_meters(payload.latitude, payload.longitude, qlat, qlon)
        if distance > radius:
            raise HTTPException(status_code=400, detail=f"Too far away ({round(distance)} m). Get within {round(radius)} m.")

        # Read all documents before performing transaction writes.
        completion_snap = completion_ref.get(transaction=tx)
        user_snap = user_ref.get(transaction=tx)
        user_data = user_snap.to_dict() if user_snap.exists else {}
        current_xp = int((user_data or {}).get("totalXp", 0))
        if completion_snap.exists:
            return {"success": False, "alreadyCompleted": True, "totalXp": current_xp,
                    "message": "Quest already completed. No extra XP awarded."}

        new_xp = current_xp + reward
        tx.set(user_ref, {"totalXp": new_xp}, merge=True)
        tx.create(completion_ref, {"questId": quest_id, "xpAwarded": reward,
            "completedAt": firestore.SERVER_TIMESTAMP,
            "distanceMetersAtValidation": round(distance, 2)})
        return {"success": True, "alreadyCompleted": False, "awardedXp": reward,
                "totalXp": new_xp, "message": f"Quest completed! +{reward} XP."}

    try:
        return apply_reward(db.transaction())
    except HTTPException:
        raise
    except Exception as exc:
        # Log exception details only in server logs; do not expose internals to the client.
        raise HTTPException(status_code=500, detail="Unable to validate quest. Please try again.") from exc
