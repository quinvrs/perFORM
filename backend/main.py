from typing import Dict, Optional

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from hmm_model import SquatHMMTracker


app = FastAPI(title="CoreRect HMM Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


trackers: Dict[str, SquatHMMTracker] = {}


class AnalyzeRequest(BaseModel):
    session_id: str = "default"
    exercise: str = "squat"

    knee_angle: Optional[float] = None
    hip_knee_gap_torso: Optional[float] = None


@app.get("/")
def root():
    return {
        "message": "CoreRect HMM Backend is running",
        "available_exercises": ["squat"],
    }


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/analyze")
def analyze_pose(data: AnalyzeRequest):
    exercise = data.exercise.lower().strip()

    if exercise != "squat":
        return {
            "state": "unsupported",
            "observation": "unknown",
            "reps": 0,
            "is_correct": False,
            "score": 0,
            "feedback": f"Exercise '{data.exercise}' is not supported yet.",
            "debug": {},
        }

    if data.session_id not in trackers:
        trackers[data.session_id] = SquatHMMTracker()

    tracker = trackers[data.session_id]

    result = tracker.update(
        knee_angle=data.knee_angle,
        hip_knee_gap_torso=data.hip_knee_gap_torso,
    )

    return {
        "state": result.state,
        "observation": result.observation,
        "reps": result.reps,
        "is_correct": result.is_correct,
        "score": result.score,
        "feedback": result.feedback,
        "debug": result.debug,
    }


@app.post("/reset/{session_id}")
def reset_session(session_id: str):
    if session_id in trackers:
        trackers[session_id].reset()

    return {
        "status": "reset",
        "session_id": session_id,
    }