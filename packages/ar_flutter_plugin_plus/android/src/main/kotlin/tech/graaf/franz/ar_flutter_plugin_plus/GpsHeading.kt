package tech.graaf.franz.ar_flutter_plugin_plus

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import kotlin.math.atan2
import kotlin.math.hypot

/** True-north bearing of the rear camera (-device Z), independent of display rotation. */
internal class GpsHeading(context: Context) : SensorEventListener {
    private val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val sensor = manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private data class Sample(val matrix: FloatArray, val timestamp: Long, val accuracy: Int, val headingError: Float)
    @Volatile private var sample: Sample? = null
    private var registered = false
    fun start(): Boolean {
        if (sensor == null) return false
        if (!registered) registered = manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)
        return registered
    }
    fun stop() {
        manager.unregisterListener(this)
        registered = false
        sample = null
    }
    override fun onSensorChanged(event: SensorEvent) {
        val rotation = FloatArray(9)
        SensorManager.getRotationMatrixFromVector(rotation, event.values)
        sample = Sample(rotation, event.timestamp, event.accuracy, if(event.values.size >= 5) event.values[4] else -1f)
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        if (accuracy < SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM) sample = null
    }
    fun bearing(latitude: Double, longitude: Double, altitude: Double): Double? {
        val reading = sample ?: return null
        if (SystemClock.elapsedRealtimeNanos()-reading.timestamp > 2_000_000_000L ||
            reading.accuracy < SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM ||
            reading.headingError > Math.toRadians(25.0)) return null
        val east = -reading.matrix[2].toDouble()
        val north = -reading.matrix[5].toDouble()
        if (hypot(east,north) < 0.25) return null
        val declination = GeomagneticField(latitude.toFloat(),longitude.toFloat(),altitude.toFloat(),System.currentTimeMillis()).declination
        return atan2(east,north) + Math.toRadians(declination.toDouble())
    }
}
