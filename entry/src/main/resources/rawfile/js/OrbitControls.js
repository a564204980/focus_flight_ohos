(function () {
  class OrbitControls extends THREE.EventDispatcher {
    constructor(object, domElement) {
      super();
      this.object = object;
      this.domElement = domElement;

      this.enabled = true;
      this.target = new THREE.Vector3();

      this.minDistance = 6;
      this.maxDistance = 120;

      this.autoRotate = true;
      this.autoRotateSpeed = 1.5; // rpm

      let isPointerDown = false;
      let previousPointerPosition = { x: 0, y: 0 };
      let previousPinchDistance = 0;

      const scope = this;

      this.zoomIn = function (factor = 0.85) {
        const offset = new THREE.Vector3().subVectors(scope.object.position, scope.target);
        let radius = offset.length() * factor;
        radius = Math.max(scope.minDistance, Math.min(scope.maxDistance, radius));
        offset.setLength(radius);
        scope.object.position.copy(scope.target).add(offset);
        scope.object.lookAt(scope.target);
      };

      this.zoomOut = function (factor = 1.18) {
        const offset = new THREE.Vector3().subVectors(scope.object.position, scope.target);
        let radius = offset.length() * factor;
        radius = Math.max(scope.minDistance, Math.min(scope.maxDistance, radius));
        offset.setLength(radius);
        scope.object.position.copy(scope.target).add(offset);
        scope.object.lookAt(scope.target);
      };

      function getTouchDistance(touches) {
        const dx = touches[0].clientX - touches[1].clientX;
        const dy = touches[0].clientY - touches[1].clientY;
        return Math.sqrt(dx * dx + dy * dy);
      }

      function onPointerDown(event) {
        if (!scope.enabled) return;
        if (event.touches && event.touches.length === 2) {
          previousPinchDistance = getTouchDistance(event.touches);
          return;
        }
        isPointerDown = true;
        previousPointerPosition = {
          x: event.clientX || (event.touches && event.touches[0].clientX) || 0,
          y: event.clientY || (event.touches && event.touches[0].clientY) || 0
        };
      }

      function onPointerMove(event) {
        if (!scope.enabled) return;

        // 双指捏合手势缩放 (Touch Pinch Zoom)
        if (event.touches && event.touches.length === 2) {
          event.preventDefault();
          const currentPinchDistance = getTouchDistance(event.touches);
          if (previousPinchDistance > 0) {
            const factor = previousPinchDistance / currentPinchDistance;
            if (factor > 1.02) {
              scope.zoomOut(1.04);
            } else if (factor < 0.98) {
              scope.zoomIn(0.96);
            }
          }
          previousPinchDistance = currentPinchDistance;
          return;
        }

        if (!isPointerDown) return;

        const currentX = event.clientX || (event.touches && event.touches[0].clientX) || 0;
        const currentY = event.clientY || (event.touches && event.touches[0].clientY) || 0;

        const deltaX = currentX - previousPointerPosition.x;
        const deltaY = currentY - previousPointerPosition.y;

        const theta = deltaX * 0.008;
        const phi = deltaY * 0.008;

        const offset = new THREE.Vector3().subVectors(scope.object.position, scope.target);

        let radius = offset.length();
        let thetaAngle = Math.atan2(offset.x, offset.z);
        let phiAngle = Math.atan2(Math.sqrt(offset.x * offset.x + offset.z * offset.z), offset.y);

        thetaAngle -= theta;
        phiAngle -= phi;

        phiAngle = Math.max(0.1, Math.min(Math.PI - 0.1, phiAngle));

        offset.x = radius * Math.sin(phiAngle) * Math.sin(thetaAngle);
        offset.y = radius * Math.cos(phiAngle);
        offset.z = radius * Math.sin(phiAngle) * Math.cos(thetaAngle);

        scope.object.position.copy(scope.target).add(offset);
        scope.object.lookAt(scope.target);

        previousPointerPosition = { x: currentX, y: currentY };
      }

      function onPointerUp() {
        isPointerDown = false;
        previousPinchDistance = 0;
      }

      function onWheel(event) {
        if (!scope.enabled) return;
        event.preventDefault();

        const delta = event.deltaY;
        if (delta > 0) {
          scope.zoomOut(1.1);
        } else {
          scope.zoomIn(0.9);
        }
      }

      this.update = function () {
        if (scope.autoRotate && !isPointerDown) {
          const offset = new THREE.Vector3().subVectors(scope.object.position, scope.target);
          let radius = offset.length();
          let thetaAngle = Math.atan2(offset.x, offset.z);
          let phiAngle = Math.atan2(Math.sqrt(offset.x * offset.x + offset.z * offset.z), offset.y);

          thetaAngle += (scope.autoRotateSpeed * Math.PI) / 1800;

          offset.x = radius * Math.sin(phiAngle) * Math.sin(thetaAngle);
          offset.y = radius * Math.cos(phiAngle);
          offset.z = radius * Math.sin(phiAngle) * Math.cos(thetaAngle);

          scope.object.position.copy(scope.target).add(offset);
          scope.object.lookAt(scope.target);
        }
      };

      this.domElement.addEventListener('pointerdown', onPointerDown, false);
      this.domElement.addEventListener('pointermove', onPointerMove, false);
      this.domElement.addEventListener('pointerup', onPointerUp, false);
      this.domElement.addEventListener('touchstart', onPointerDown, false);
      this.domElement.addEventListener('touchmove', onPointerMove, false);
      this.domElement.addEventListener('touchend', onPointerUp, false);
      this.domElement.addEventListener('wheel', onWheel, { passive: false });
    }
  }

  THREE.OrbitControls = OrbitControls;
})();
