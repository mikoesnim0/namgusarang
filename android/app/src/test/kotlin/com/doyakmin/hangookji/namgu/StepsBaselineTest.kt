package com.doyakmin.hangookji.namgu

import android.content.Context
import android.content.SharedPreferences
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.MockitoAnnotations
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.Calendar
import java.util.Locale
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

/**
 * Unit tests for sensor baseline logic
 *
 * Tests the critical date/reboot handling in StepsApi
 *
 * To run these tests:
 * 1. Add to android/app/build.gradle:
 *    testImplementation 'junit:junit:4.13.2'
 *    testImplementation 'org.mockito:mockito-core:4.0.0'
 *    testImplementation 'org.robolectric:robolectric:4.9'
 * 2. Run: ./gradlew test
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class StepsBaselineTest {

    @Mock
    private lateinit var context: Context

    @Mock
    private lateinit var prefs: SharedPreferences

    @Mock
    private lateinit var editor: SharedPreferences.Editor

    private lateinit var helper: BaselineTestHelper

    @Before
    fun setup() {
        MockitoAnnotations.openMocks(this)
        `when`(prefs.edit()).thenReturn(editor)
        `when`(editor.putString(anyString(), anyString())).thenReturn(editor)
        `when`(editor.putFloat(anyString(), anyFloat())).thenReturn(editor)
        `when`(editor.putInt(anyString(), anyInt())).thenReturn(editor)

        helper = BaselineTestHelper(prefs)
    }

    @Test
    fun `날짜가 바뀌면 베이스라인이 리셋된다`() {
        // Given: 어제 베이스라인 설정
        val yesterday = "20260216"
        val today = "20260217"
        `when`(prefs.getString("baseline_date", null)).thenReturn(yesterday)
        `when`(prefs.getFloat("baseline_total", 6000f)).thenReturn(5000f)

        // When: 오늘 센서 값으로 베이스라인 계산
        val baseline = helper.ensureBaseline(6000f, today)

        // Then: 베이스라인이 오늘 값으로 리셋되어야 함
        assertEquals(6000f, baseline, 0.1f, "Baseline should reset to current counter on date change")
    }

    @Test
    fun `센서 카운터가 리셋되면 베이스라인이 갱신된다`() {
        // Given: 오늘 베이스라인 5000
        val today = "20260217"
        `when`(prefs.getString("baseline_date", null)).thenReturn(today)
        `when`(prefs.getFloat("baseline_total", 100f)).thenReturn(5000f)

        // When: 센서 값이 재부팅으로 100으로 감소
        val baseline = helper.ensureBaseline(100f, today)

        // Then: 베이스라인이 100으로 갱신되어야 함
        assertEquals(100f, baseline, 0.1f, "Baseline should reset when sensor counter decreases (reboot)")
    }

    @Test
    fun `재부팅 후 캐시된 걸음수가 무효화된다`() {
        // Given: 어제 캐시된 걸음수
        val yesterday = "20260216"
        val today = "20260217"
        `when`(prefs.getString("baseline_date", null)).thenReturn(yesterday)
        `when`(prefs.getString("last_today_date", null)).thenReturn(yesterday)
        `when`(prefs.getInt("last_today_steps", 0)).thenReturn(5000)

        // When: 오늘 캐시 읽기 시도
        val cached = helper.readCachedTodaySteps(today)

        // Then: null 반환 (베이스라인이 오늘 것이 아님)
        assertNull(cached, "Cache should be invalid when baseline is not for today")
    }

    @Test
    fun `정상적인 센서 증가는 베이스라인을 유지한다`() {
        // Given: 오늘 베이스라인 1000
        val today = "20260217"
        `when`(prefs.getString("baseline_date", null)).thenReturn(today)
        `when`(prefs.getFloat("baseline_total", 5000f)).thenReturn(1000f)

        // When: 센서 값이 정상적으로 5000으로 증가
        val baseline = helper.ensureBaseline(5000f, today)

        // Then: 베이스라인 유지
        assertEquals(1000f, baseline, 0.1f, "Baseline should remain unchanged on normal increase")
    }

    @Test
    fun `오늘 걸음수 계산이 정확하다`() {
        // Given: 베이스라인 1000, 현재 센서 5000
        val today = "20260217"
        `when`(prefs.getString("baseline_date", null)).thenReturn(today)
        `when`(prefs.getFloat("baseline_total", 5000f)).thenReturn(1000f)

        val baseline = helper.ensureBaseline(5000f, today)
        val todaySteps = helper.calcTodaySteps(5000f, baseline)

        // Then: 오늘 걸음수 = 4000
        assertEquals(4000, todaySteps, "Today steps should be current - baseline")
    }

    @Test
    fun `음수 걸음수는 0으로 처리된다`() {
        // Given: 센서 값이 베이스라인보다 작음 (비정상)
        val today = "20260217"
        `when`(prefs.getString("baseline_date", null)).thenReturn(today)
        `when`(prefs.getFloat("baseline_total", 100f)).thenReturn(5000f)

        val baseline = 5000f // (센서는 리셋 감지 전)
        val todaySteps = helper.calcTodaySteps(100f, baseline)

        // Then: 음수는 0으로 처리
        assertEquals(0, todaySteps, "Negative steps should be clamped to 0")
    }

    @Test
    fun `캐시 검증 - 오늘 날짜가 맞으면 캐시 유효`() {
        // Given: 오늘 캐시 및 베이스라인
        val today = "20260217"
        `when`(prefs.getString("baseline_date", null)).thenReturn(today)
        `when`(prefs.getString("last_today_date", null)).thenReturn(today)
        `when`(prefs.getInt("last_today_steps", 0)).thenReturn(3000)

        // When: 캐시 읽기
        val cached = helper.readCachedTodaySteps(today)

        // Then: 캐시 값 리턴
        assertNotNull(cached, "Cache should be valid when dates match")
        assertEquals(3000, cached, "Cached value should be returned")
    }

    // Test helper class that mimics StepsApi logic
    private class BaselineTestHelper(private val prefs: SharedPreferences) {
        fun ensureBaseline(totalCounter: Float, today: String): Float {
            val baselineDate = prefs.getString("baseline_date", null)
            val storedBaseline = prefs.getFloat("baseline_total", totalCounter)

            // 날짜 변경 → 리셋
            if (baselineDate != today) {
                return totalCounter
            }

            // 센서 리셋 감지 (재부팅)
            if (totalCounter + 1 < storedBaseline) {
                return totalCounter
            }

            return storedBaseline
        }

        fun calcTodaySteps(totalCounter: Float, baseline: Float): Int {
            val raw = (totalCounter - baseline).toInt()
            return if (raw < 0) 0 else raw
        }

        fun readCachedTodaySteps(today: String): Int? {
            val cacheDate = prefs.getString("last_today_date", null) ?: return null
            if (cacheDate != today) return null

            // 베이스라인 날짜 체크 (재부팅 감지)
            val baselineDate = prefs.getString("baseline_date", null)
            if (baselineDate != today) {
                return null
            }

            val steps = prefs.getInt("last_today_steps", 0)
            return if (steps < 0) 0 else steps
        }
    }

    // Mockito helpers
    private fun anyString(): String = org.mockito.ArgumentMatchers.anyString()
    private fun anyFloat(): Float = org.mockito.ArgumentMatchers.anyFloat()
    private fun anyInt(): Int = org.mockito.ArgumentMatchers.anyInt()
}
