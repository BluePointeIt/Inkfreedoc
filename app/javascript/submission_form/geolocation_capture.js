// Geolocation capture module for signing metadata
// Captures GPS coordinates (with permission) and local time data

const geolocationState = {
  latitude: null,
  longitude: null,
  accuracy: null,
  permissionGranted: false,
  localTime: null,
  localTimezone: null,
  requested: false
}

function requestGeolocation () {
  if (geolocationState.requested) return

  geolocationState.requested = true
  geolocationState.localTime = new Date().toISOString()
  geolocationState.localTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone

  if (!navigator.geolocation) {
    geolocationState.permissionGranted = false
    return
  }

  navigator.geolocation.getCurrentPosition(
    (position) => {
      geolocationState.latitude = position.coords.latitude
      geolocationState.longitude = position.coords.longitude
      geolocationState.accuracy = position.coords.accuracy
      geolocationState.permissionGranted = true
    },
    () => {
      geolocationState.permissionGranted = false
    },
    {
      enableHighAccuracy: true,
      timeout: 10000,
      maximumAge: 60000
    }
  )
}

function appendGeolocationToFormData (formData) {
  // Update local time at submission moment
  geolocationState.localTime = new Date().toISOString()
  geolocationState.localTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone

  formData.append('local_time', geolocationState.localTime)
  formData.append('local_timezone', geolocationState.localTimezone)

  if (geolocationState.permissionGranted) {
    formData.append('gps_latitude', geolocationState.latitude)
    formData.append('gps_longitude', geolocationState.longitude)
    formData.append('gps_accuracy', geolocationState.accuracy)
    formData.append('gps_permission_granted', 'true')
  } else {
    formData.append('gps_permission_granted', 'false')
  }
}

export { requestGeolocation, appendGeolocationToFormData, geolocationState }
