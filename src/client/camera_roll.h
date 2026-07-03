#pragma once

#include <irrlichttypes.h>
#include <vector2d.h>

class LocalPlayer;

class CameraRollController
{
public:
	CameraRollController();

	// Called each frame — handles keyboard input and auto-reset
	void step(f32 dtime, LocalPlayer *player,
		bool roll_left, bool roll_right, bool any_movement_key);

	// Called when mouse or other input should cancel idle decay
	void resetIdleTimer();

	// Adjust mouse delta for camera roll
	// Returns yaw_delta, pitch_delta given raw input
	void applyAdaptiveMouse(LocalPlayer *player,
		f32 raw_dx, f32 raw_dy,
		f32 &out_yaw, f32 &out_pitch);

private:
	f32 m_idle_time = 0.0f;
	f32 m_at_reset_start = 0.0f;
	f32 m_reset_timer = -1.0f;
};
