<script setup>
import AMapLoader from '@amap/amap-jsapi-loader'

const map = ref(null)
const currentLocationMarker = ref(null)
const geolocation = ref(null)
const Amap = ref(null)

onMounted(() => {
  window._AMapSecurityConfig = {
    securityJsCode: 'bf61b5b8457d13555c3d9e36321102b1',
  }
  AMapLoader.load({
    key: 'bf61b5b8457d13555c3d9e36321102b1',
    version: '2.0',
    plugins: ['AMap.Scale', 'AMap.MarkerCluster', 'AMap.Geolocation'],
  })
    .then((AmapInstance) => {
      Amap.value = AmapInstance
      // 创建地图
      map.value = new AmapInstance.Map('container', {
        viewMode: '3D',
        zoom: 11,
      })

      // 初始化定位功能
      AmapInstance.plugin('AMap.Geolocation', () => {
        geolocation.value = new AmapInstance.Geolocation({
          enableHighAccuracy: true, // 是否使用高精度定位，默认：true
          timeout: 10000, // 设置定位超时时间，默认：无穷大
          offset: [10, 20], // 定位按钮的停靠位置的偏移量
          zoomToAccuracy: true, // 定位成功后调整地图视野范围使定位位置及精度范围视野内可见，默认：false
          position: 'RB', // 定位按钮的排放位置,  RB表示右下
        })

        geolocation.value.getCurrentPosition((status, result) => {
          if (status === 'complete') {
            onComplete(result)
          }
          else {
            onError(result)
          }
        })

        function onComplete(data) {
          // data是具体的定位信息
          console.warn('定位成功：', data)
          // 获取定位的经纬度
          const position = data.position || data.location
          if (position) {
            // 设置地图中心为定位位置
            const center = [
              position.lng || position.longitude,
              position.lat || position.latitude,
            ]
            map.value.setCenter(center)

            // 如果已存在标记，先移除
            if (currentLocationMarker.value) {
              currentLocationMarker.value.setMap(null)
            }

            // 创建当前位置标记 - 使用蓝色圆点，区别于咖啡店的绿色标记
            const markerContent
              = '<div style="background-color: rgba(0, 123, 255, 0.9); height: 20px; width: 20px; border: 3px solid #ffffff; border-radius: 50%; box-shadow: rgba(0, 123, 255, 0.6) 0px 0px 8px;"></div>'
            const marker = new AmapInstance.Marker({
              position: center,
              content: markerContent,
              offset: new AmapInstance.Pixel(-10, -10),
            })

            // 将标记添加到地图
            marker.setMap(map.value)
            currentLocationMarker.value = marker
          }
        }

        function onError(data) {
          // 定位出错
          console.error('定位失败：', data)
        }
      })

      fetch('/store.json')
        .then(res => res.json())
        .then((json) => {
          const data = json.data || []
          const points = data
            .filter(
              d => d.coordinates?.longitude != null && d.coordinates?.latitude != null,
            )
            .map(d => ({ lnglat: [d.coordinates.longitude, d.coordinates.latitude] }))
          if (points.length) {
            const gridSize = 60
            const count = points.length

            // 自定义聚合点样式 - 星巴克绿色系渐变
            const _renderClusterMarker = function (context) {
              const factor = (context.count / count) ** (1 / 18)
              const div = document.createElement('div')
              // 星巴克主色 rgb(0, 100, 64) 对应 HSL 约 hsl(158, 100%, 20%)
              // 从浅绿色(140)渐变到星巴克深绿色(158)
              const Hue = 140 + factor * 18
              // 从较亮的绿色(50%)渐变到较暗的星巴克绿(20%)
              const lightness = 50 - factor * 30
              const bgColor = `hsla(${Hue},100%,${lightness}%,0.7)`
              const fontColor = '#ffffff'
              const borderColor = `hsl(${Hue},100%,${lightness}%)`
              const shadowColor = `hsla(${Hue},100%,${lightness + 20}%,0.5)`
              div.style.backgroundColor = bgColor
              const size = Math.round(30 + (context.count / count) ** (1 / 5) * 20)
              div.style.width = div.style.height = `${size}px`
              div.style.border = `solid 1px ${borderColor}`
              div.style.borderRadius = `${size / 2}px`
              div.style.boxShadow = `0 0 5px ${shadowColor}`
              div.innerHTML = context.count
              div.style.lineHeight = `${size}px`
              div.style.color = fontColor
              div.style.fontSize = '14px'
              div.style.textAlign = 'center'
              context.marker.setOffset(new AmapInstance.Pixel(-size / 2, -size / 2))
              context.marker.setContent(div)
            }

            // 自定义非聚合点样式 - 星巴克主色
            const _renderMarker = function (context) {
              const content
                = '<div style="background-color: rgba(0, 100, 64, 0.8); height: 18px; width: 18px; border: 2px solid rgb(0, 100, 64); border-radius: 12px; box-shadow: rgba(0, 100, 64, 0.6) 0px 0px 4px;"></div>'
              const offset = new AmapInstance.Pixel(-9, -9)
              context.marker.setContent(content)
              context.marker.setOffset(offset)
            }

            // 创建完全自定义的点聚合
            const _cluster = new AmapInstance.MarkerCluster(map.value, points, {
              gridSize, // 设置网格像素大小
              renderClusterMarker: _renderClusterMarker, // 自定义聚合点样式
              renderMarker: _renderMarker, // 自定义非聚合点样式
            })

            // 监听聚合点点击事件，实现平滑放大
            _cluster.on('click', (e) => {
              // 获取点击的聚合点位置（多种方式尝试，确保兼容性）
              let center = null

              // 方式1: 从事件对象获取位置
              if (e.lnglat) {
                center = [e.lnglat.lng, e.lnglat.lat]
              }
              // 方式2: 从标记对象获取位置
              else if (e.target && e.target.getPosition) {
                const position = e.target.getPosition()
                if (position) {
                  center = [position.lng, position.lat]
                }
              }
              // 方式3: 从聚合数据计算中心点
              else if (e.clusterData && e.clusterData.length > 0) {
                let totalLng = 0
                let totalLat = 0
                let validCount = 0
                e.clusterData.forEach((item) => {
                  const lnglat = item.lnglat || item.position
                  if (Array.isArray(lnglat) && lnglat.length >= 2) {
                    totalLng += lnglat[0]
                    totalLat += lnglat[1]
                    validCount++
                  }
                })
                if (validCount > 0) {
                  center = [totalLng / validCount, totalLat / validCount]
                }
              }

              if (center) {
                // 获取当前缩放级别和中心点
                const currentZoom = map.value.getZoom()
                const currentCenter = map.value.getCenter()
                // 计算目标缩放级别（放大2级，但不超过最大缩放级别18）
                const targetZoom = Math.min(currentZoom + 2, 18)

                // 使用平滑的缓动动画函数
                const easeOutCubic = t => 1 - (1 - t) ** 3
                const duration = 800 // 动画时长800ms
                const startTime = Date.now()
                const startZoom = currentZoom
                const zoomDiff = targetZoom - startZoom
                const startCenter = [currentCenter.lng, currentCenter.lat]
                const centerDiff = [
                  center[0] - startCenter[0],
                  center[1] - startCenter[1],
                ]

                // 平滑动画函数
                const animate = () => {
                  const elapsed = Date.now() - startTime
                  const progress = Math.min(elapsed / duration, 1)
                  const easedProgress = easeOutCubic(progress)

                  // 同时更新缩放和中心点
                  const currentZoomValue = startZoom + zoomDiff * easedProgress
                  const currentCenterValue = [
                    startCenter[0] + centerDiff[0] * easedProgress,
                    startCenter[1] + centerDiff[1] * easedProgress,
                  ]

                  map.value.setZoomAndCenter(currentZoomValue, currentCenterValue, false)

                  if (progress < 1) {
                    requestAnimationFrame(animate)
                  }
                  else {
                    // 确保最终精确到达目标值
                    map.value.setZoomAndCenter(targetZoom, center, false)
                  }
                }

                // 开始动画
                requestAnimationFrame(animate)
              }
            })
          }
        })
        .catch(e => console.error(e))
    })
    .catch(e => console.error(e))
})

// 定位到当前位置的函数
function locateToCurrentPosition() {
  if (geolocation.value && map.value) {
    geolocation.value.getCurrentPosition((status, result) => {
      if (status === 'complete') {
        const position = result.position || result.location
        if (position && Amap.value) {
          // 设置地图中心为定位位置
          const center = [
            position.lng || position.longitude,
            position.lat || position.latitude,
          ]
          map.value.setCenter(center)

          // 如果已存在标记，先移除
          if (currentLocationMarker.value) {
            currentLocationMarker.value.setMap(null)
          }

          // 创建当前位置标记 - 使用蓝色圆点，区别于咖啡店的绿色标记
          const markerContent
            = '<div style="background-color: rgba(0, 123, 255, 0.9); height: 20px; width: 20px; border: 3px solid #ffffff; border-radius: 50%; box-shadow: rgba(0, 123, 255, 0.6) 0px 0px 8px;"></div>'
          const marker = new Amap.value.Marker({
            position: center,
            content: markerContent,
            offset: new Amap.value.Pixel(-10, -10),
          })

          // 将标记添加到地图
          marker.setMap(map.value)
          currentLocationMarker.value = marker
        }
      }
      else {
        console.error('定位失败：', result)
      }
    })
  }
}
</script>

<template>
  <div
    class="h-12 w-full flex items-center justify-between gap-2 p-2"
    border="b gray-200"
    fixed
    left-0
    right-0
    top-0
    z-10
  >
    <div class="flex items-center gap-2">
      <div class="i-carbon-search" />
    </div>
    <div class="flex items-center gap-2">
      <div class="i-line-md-coffee-loop text-2xl" />
      <div text-black font-bold>
        COFFEE
      </div>
    </div>
    <div class="flex items-center" @click="locateToCurrentPosition">
      <div class="i-carbon-location-heart cursor-pointer" />
    </div>
  </div>
  <div id="container" class="mt-3rem h-[calc(100vh-3rem)] w-full" />
</template>

<style scoped></style>
