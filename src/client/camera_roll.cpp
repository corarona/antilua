#include "client/camera_roll.h"
#include "client/localplayer.h"
#include "settings.h"
#include "util/numeric.h"
#include <cmath>

CameraRollController::CameraRollController() = default;

void CameraRollController::resetIdleTimer()
{
	m_idle_time = 0.0f;
}

// Force CI rerun - integration test fixes in 2b1b55c36
void CameraRollController::step(f32 dtime, LocalPlayer *player,
	bool roll_left, bool roll_right, bool any_movement_key)
{
	m_idle_time += dtime;

	if (roll_left || roll_right || any_movement_key) {
		m_idle_time = 0.0f;
		m_reset_timer = -1.0f;
	}

	// Keyboard roll input
	if (roll_left || roll_right) {
		f32 roll_speed = g_settings->getFloat("camera_roll_speed", 0.0f, 720.0f);
		f32 roll_max = g_settings->getFloat("camera_roll_max", 0.0f, 360.0f);
		f32 current_roll = player->getCameraRoll() * core::RADTODEG;
		if (roll_left)
			current_roll -= roll_speed * dtime;
		if (roll_right)
			current_roll += roll_speed * dtime;
		if (roll_max >= 360.0f) {
			current_roll = fmod(current_roll, 360.0f);
			if (current_roll > 180.0f)
				current_roll -= 360.0f;
			if (current_roll <= -180.0f)
				current_roll += 360.0f;
		} else {
			current_roll = rangelim(current_roll, -roll_max, roll_max);
		}
		player->setCameraRoll(current_roll * core::DEGTORAD);
	}

	// Auto-reset
	if (g_settings->getBool("camera_roll_auto_reset")) {
		f32 current_roll = player->getCameraRoll();
		if (current_roll != 0.0f) {
			f32 delay = g_settings->getFloat("camera_roll_auto_reset_delay");
			f32 duration = g_settings->getFloat("camera_roll_auto_reset_duration");

			if (m_idle_time >= delay) {
				if (m_reset_timer < 0.0f) {
					m_reset_timer = 0.0f;
					m_at_reset_start = current_roll;
				}
				m_reset_timer += dtime;
				f32 t = fminf(m_reset_timer / duration, 1.0f);
				f32 smooth = t * t * (3.0f - 2.0f * t);
				f32 new_roll = m_at_reset_start * (1.0f - smooth);
				player->setCameraRoll(new_roll);
				if (t >= 1.0f) {
					player->setCameraRoll(0.0f);
					m_reset_timer = -1.0f;
				}
			}
		} else {
			m_reset_timer = -1.0f;
		}
	}
}

void CameraRollController::applyAdaptiveMouse(LocalPlayer *player,
	f32 raw_dx, f32 raw_dy,
	f32 &out_yaw, f32 &out_pitch)
{
	// Start with raw deltas
	out_yaw = -raw_dx;
	out_pitch = raw_dy;

	std::string mode = g_settings->get("camera_roll_adaptive_mouse");
	if (mode != "both" && mode != "pitch")
		return;

	f32 roll = player->getCameraRoll();
	if (roll == 0.0f)
		return;

	f32 cos_r = cosf(roll);
	f32 sin_r = sinf(roll);

	if (mode == "both") {
		out_yaw = -(raw_dx * cos_r - raw_dy * sin_r);
		out_pitch = raw_dx * sin_r + raw_dy * fabsf(cos_r);
	} else {
		out_yaw = -raw_dx;
		out_pitch = raw_dy * fabsf(cos_r);
	}
}
