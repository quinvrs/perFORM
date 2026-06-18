from dataclasses import dataclass, field
from typing import Dict, List, Optional
import math
import time


EPS = 1e-12


def safe_log(value: float) -> float:
    return math.log(max(value, EPS))


@dataclass
class HMMOutput:
    state: str
    observation: str
    reps: int
    is_correct: bool
    score: int
    feedback: str
    debug: Dict = field(default_factory=dict)


class SquatHMMTracker:
    """
    Prototype Hidden Markov Model tracker for squat movement.

    Hidden states:
    standing -> descent -> bottom -> ascent -> standing

    Observations:
    upright, lowering, deep, rising, mid, unknown
    """

    def __init__(self):
        self.states = ["standing", "descent", "bottom", "ascent"]

        self.start_prob = {
            "standing": 0.85,
            "descent": 0.10,
            "bottom": 0.03,
            "ascent": 0.02,
        }

        self.transition_prob = {
            "standing": {
                "standing": 0.70,
                "descent": 0.25,
                "bottom": 0.03,
                "ascent": 0.02,
            },
            "descent": {
                "standing": 0.10,
                "descent": 0.50,
                "bottom": 0.35,
                "ascent": 0.05,
            },
            "bottom": {
                "standing": 0.05,
                "descent": 0.10,
                "bottom": 0.50,
                "ascent": 0.35,
            },
            "ascent": {
                "standing": 0.35,
                "descent": 0.10,
                "bottom": 0.05,
                "ascent": 0.50,
            },
        }

        self.emission_prob = {
            "standing": {
                "upright": 0.75,
                "lowering": 0.05,
                "deep": 0.01,
                "rising": 0.08,
                "mid": 0.10,
                "unknown": 0.01,
            },
            "descent": {
                "upright": 0.05,
                "lowering": 0.60,
                "deep": 0.05,
                "rising": 0.03,
                "mid": 0.25,
                "unknown": 0.02,
            },
            "bottom": {
                "upright": 0.01,
                "lowering": 0.05,
                "deep": 0.70,
                "rising": 0.03,
                "mid": 0.20,
                "unknown": 0.01,
            },
            "ascent": {
                "upright": 0.08,
                "lowering": 0.03,
                "deep": 0.02,
                "rising": 0.60,
                "mid": 0.25,
                "unknown": 0.02,
            },
        }

        self.observation_history: List[str] = []
        self.max_history = 20

        self.previous_knee_angle: Optional[float] = None
        self.previous_state: Optional[str] = None

        self.reps = 0
        self.seen_bottom = False
        self.last_rep_time = 0.0

    def reset(self):
        self.observation_history.clear()
        self.previous_knee_angle = None
        self.previous_state = None
        self.reps = 0
        self.seen_bottom = False
        self.last_rep_time = 0.0

    def update(
        self,
        knee_angle: Optional[float],
        hip_knee_gap_torso: Optional[float],
    ) -> HMMOutput:
        observation = self._make_observation(knee_angle, hip_knee_gap_torso)

        self.observation_history.append(observation)
        if len(self.observation_history) > self.max_history:
            self.observation_history.pop(0)

        state = self._viterbi(self.observation_history)

        rep_counted = False
        now = time.time()

        if state == "bottom":
            self.seen_bottom = True

        if (
            self.seen_bottom
            and state == "standing"
            and self.previous_state in ["bottom", "ascent"]
            and now - self.last_rep_time >= 0.45
        ):
            self.reps += 1
            self.last_rep_time = now
            self.seen_bottom = False
            rep_counted = True

        is_correct, score, feedback = self._evaluate_form(
            state=state,
            observation=observation,
            knee_angle=knee_angle,
            hip_knee_gap_torso=hip_knee_gap_torso,
            rep_counted=rep_counted,
        )

        self.previous_state = state
        if knee_angle is not None:
            self.previous_knee_angle = knee_angle

        return HMMOutput(
            state=state,
            observation=observation,
            reps=self.reps,
            is_correct=is_correct,
            score=score,
            feedback=feedback,
            debug={
                "history": self.observation_history,
                "previous_state": self.previous_state,
                "seen_bottom": self.seen_bottom,
                "knee_angle": knee_angle,
                "hip_knee_gap_torso": hip_knee_gap_torso,
            },
        )

    def _make_observation(
        self,
        knee_angle: Optional[float],
        hip_knee_gap_torso: Optional[float],
    ) -> str:
        if knee_angle is None:
            return "unknown"

        if knee_angle >= 160:
            return "upright"

        if knee_angle <= 105:
            return "deep"

        if hip_knee_gap_torso is not None and hip_knee_gap_torso <= 0.30:
            return "deep"

        if self.previous_knee_angle is not None:
            change = knee_angle - self.previous_knee_angle

            # In squat, knee angle decreases while going down.
            if change <= -2.0:
                return "lowering"

            # Knee angle increases while standing back up.
            if change >= 2.0:
                return "rising"

        return "mid"

    def _viterbi(self, observations: List[str]) -> str:
        if not observations:
            return "standing"

        v = [{}]
        path = {}

        first_obs = observations[0]

        for state in self.states:
            v[0][state] = safe_log(self.start_prob[state]) + safe_log(
                self.emission_prob[state].get(first_obs, EPS)
            )
            path[state] = [state]

        for t in range(1, len(observations)):
            v.append({})
            new_path = {}
            obs = observations[t]

            for current_state in self.states:
                candidates = []

                for previous_state in self.states:
                    probability = (
                        v[t - 1][previous_state]
                        + safe_log(self.transition_prob[previous_state][current_state])
                        + safe_log(self.emission_prob[current_state].get(obs, EPS))
                    )

                    candidates.append((probability, previous_state))

                best_probability, best_previous_state = max(candidates)

                v[t][current_state] = best_probability
                new_path[current_state] = path[best_previous_state] + [current_state]

            path = new_path

        best_state = max(self.states, key=lambda state: v[-1][state])
        return best_state

    def _evaluate_form(
        self,
        state: str,
        observation: str,
        knee_angle: Optional[float],
        hip_knee_gap_torso: Optional[float],
        rep_counted: bool,
    ):
        if observation == "unknown":
            return False, 0, "Body landmarks are not clear."

        if rep_counted:
            return True, 100, "Rep counted. Good sequence."

        if state == "standing":
            return True, 90, "Standing position detected."

        if state == "descent":
            return True, 85, "Going down. Keep the movement controlled."

        if state == "bottom":
            if knee_angle is not None and knee_angle <= 105:
                return True, 95, "Good squat depth."

            if hip_knee_gap_torso is not None and hip_knee_gap_torso <= 0.30:
                return True, 90, "Good bottom position."

            return False, 60, "Go slightly lower for better squat depth."

        if state == "ascent":
            return True, 85, "Going up. Return to standing position."

        return False, 50, "Movement sequence is unclear."