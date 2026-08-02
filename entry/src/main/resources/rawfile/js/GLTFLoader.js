(function () {
  class GLTFLoader extends THREE.Loader {
    constructor(manager) {
      super(manager);
      this.dracoLoader = null;
      this.ktx2Loader = null;
      this.meshoptDecoder = null;
      this.pluginCallbacks = [];
    }

    load(url, onLoad, onProgress, onError) {
      const scope = this;
      const loader = new THREE.FileLoader(this.manager);
      loader.setPath(this.path);
      loader.setResponseType('arraybuffer');
      loader.setRequestHeader(this.requestHeader);
      loader.setWithCredentials(this.withCredentials);

      loader.load(url, function (data) {
        try {
          scope.parse(data, '', function (gltf) {
            onLoad(gltf);
          }, onError);
        } catch (e) {
          if (onError) {
            onError(e);
          } else {
            console.error(e);
          }
          scope.manager.itemError(url);
        }
      }, onProgress, onError);
    }

    parse(data, path, onLoad, onError) {
      let content;
      const magic = THREE.LoaderUtils.decodeText(new Uint8Array(data, 0, 4));

      if (magic === 'glTF') {
        const parseGLTFBinary = function (data) {
          const header = new Uint32Array(data, 0, 3);
          const version = header[1];
          const length = header[2];

          if (version !== 2) {
            throw new Error('GLTFLoader: Unsupported binary glTF version ' + version);
          }

          const chunkHeader = new Uint32Array(data, 12, 2);
          const chunkType = chunkHeader[1];
          let bodyData = null;

          if (chunkType === 0x4E4F534A) { // JSON
            const jsonBuffer = data.slice(20, 20 + chunkHeader[0]);
            content = THREE.LoaderUtils.decodeText(new Uint8Array(jsonBuffer));
          } else {
            throw new Error('GLTFLoader: First chunk is not JSON');
          }

          if (data.byteLength > 20 + chunkHeader[0]) {
            const binChunkHeader = new Uint32Array(data, 20 + chunkHeader[0], 2);
            if (binChunkHeader[1] === 0x004E4942) { // BIN
              bodyData = data.slice(20 + chunkHeader[0] + 8, 20 + chunkHeader[0] + 8 + binChunkHeader[0]);
            }
          }

          return { json: JSON.parse(content), body: bodyData };
        };

        const binData = parseGLTFBinary(data);
        this._parseJSON(binData.json, binData.body, path, onLoad, onError);
      } else {
        content = THREE.LoaderUtils.decodeText(new Uint8Array(data));
        this._parseJSON(JSON.parse(content), null, path, onLoad, onError);
      }
    }

    _parseJSON(json, bodyData, path, onLoad, onError) {
      const parser = new GLTFParser(json, bodyData, path, this);
      parser.parse(onLoad, onError);
    }
  }

  class GLTFParser {
    constructor(json, bodyData, path, options) {
      this.json = json;
      this.bodyData = bodyData;
      this.path = path;
      this.options = options;
      this.cache = new Map();
    }

    parse(onLoad, onError) {
      const scope = this;
      const json = this.json;

      this.getDependencies('scene').then(function (scenes) {
        const scene = scenes[json.scene || 0];
        const result = {
          scene: scene,
          scenes: scenes,
          cameras: [],
          animations: [],
          asset: json.asset,
          parser: scope,
          userData: {}
        };
        onLoad(result);
      }).catch(onError);
    }

    getDependencies(type) {
      let dependencies = this.cache.get(type);

      if (!dependencies) {
        const scope = this;
        const defs = this.json[type + (type === 'mesh' ? 'es' : 's')] || [];

        dependencies = Promise.all(defs.map(function (def, index) {
          return scope.loadDependency(type, index);
        }));

        this.cache.set(type, dependencies);
      }

      return dependencies;
    }

    loadDependency(type, index) {
      const scope = this;
      const def = this.json[type + (type === 'mesh' ? 'es' : 's')][index];

      switch (type) {
        case 'scene':
          return this.loadScene(index);
        case 'node':
          return this.loadNode(index);
        case 'mesh':
          return this.loadMesh(index);
        case 'accessor':
          return this.loadAccessor(index);
        case 'bufferView':
          return this.loadBufferView(index);
        case 'material':
          return this.loadMaterial(index);
        default:
          throw new Error('Unknown type ' + type);
      }
    }

    loadBufferView(bufferViewIndex) {
      const bufferViewDef = this.json.bufferViews[bufferViewIndex];
      const byteLength = bufferViewDef.byteLength || 0;
      const byteOffset = bufferViewDef.byteOffset || 0;

      if (this.bodyData) {
        return Promise.resolve(this.bodyData.slice(byteOffset, byteOffset + byteLength));
      }
      return Promise.reject(new Error('Buffer external loading not embedded in GLB'));
    }

    loadAccessor(accessorIndex) {
      const scope = this;
      const accessorDef = this.json.accessors[accessorIndex];
      const bufferViewIndex = accessorDef.bufferView;

      return this.loadDependency('bufferView', bufferViewIndex).then(function (buffer) {
        const itemSize = { 'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16 }[accessorDef.type];
        const TypedArray = {
          5120: Int8Array,
          5121: Uint8Array,
          5122: Int16Array,
          5123: Uint16Array,
          5125: Uint32Array,
          5126: Float32Array
        }[accessorDef.componentType];

        const byteOffset = accessorDef.byteOffset || 0;
        const count = accessorDef.count;
        const array = new TypedArray(buffer, byteOffset, count * itemSize);

        return new THREE.BufferAttribute(array, itemSize, accessorDef.normalized || false);
      });
    }

    loadMaterial(materialIndex) {
      const materialDef = this.json.materials ? this.json.materials[materialIndex] : {};
      const name = materialDef.name || ('Material_' + materialIndex);

      const material = new THREE.MeshStandardMaterial({
        name: name,
        color: 0xcccccc,
        roughness: 0.4,
        metalness: 0.6,
        side: THREE.DoubleSide
      });

      if (materialDef.pbrMetallicRoughness) {
        const pbr = materialDef.pbrMetallicRoughness;
        if (pbr.baseColorFactor) {
          material.color.fromArray(pbr.baseColorFactor);
        }
        if (pbr.metallicFactor !== undefined) material.metalness = pbr.metallicFactor;
        if (pbr.roughnessFactor !== undefined) material.roughness = pbr.roughnessFactor;
      }

      return Promise.resolve(material);
    }

    loadMesh(meshIndex) {
      const scope = this;
      const meshDef = this.json.meshes[meshIndex];
      const primitivesDef = meshDef.primitives;

      const pending = [];

      for (let i = 0; i < primitivesDef.length; i++) {
        const prim = primitivesDef[i];
        const pendingAttributes = [];

        for (const attributeName in prim.attributes) {
          pendingAttributes.push(scope.loadDependency('accessor', prim.attributes[attributeName]).then(function (attribute) {
            let name = attributeName.toLowerCase();
            if (name === 'position') name = 'position';
            else if (name === 'normal') name = 'normal';
            else if (name === 'texcoord_0') name = 'uv';
            return { name: name, attribute: attribute };
          }));
        }

        if (prim.indices !== undefined) {
          pendingAttributes.push(scope.loadDependency('accessor', prim.indices).then(function (attribute) {
            return { name: 'index', attribute: attribute };
          }));
        }

        const pendingMaterial = prim.material !== undefined
          ? scope.loadDependency('material', prim.material)
          : Promise.resolve(new THREE.MeshStandardMaterial({ color: 0x0EA5E9, side: THREE.DoubleSide }));

        pending.push(Promise.all([Promise.all(pendingAttributes), pendingMaterial]).then(function (results) {
          const attributes = results[0];
          const material = results[1];

          const geometry = new THREE.BufferGeometry();

          for (let a = 0; a < attributes.length; a++) {
            const name = attributes[a].name;
            const attribute = attributes[a].attribute;
            if (name === 'index') {
              geometry.setIndex(attribute);
            } else {
              geometry.setAttribute(name, attribute);
            }
          }

          if (!geometry.attributes.normal) {
            geometry.computeVertexNormals();
          }

          return new THREE.Mesh(geometry, material);
        }));
      }

      return Promise.all(pending).then(function (meshes) {
        if (meshes.length === 1) return meshes[0];
        const group = new THREE.Group();
        for (let i = 0; i < meshes.length; i++) group.add(meshes[i]);
        return group;
      });
    }

    loadNode(nodeIndex) {
      const scope = this;
      const nodeDef = this.json.nodes[nodeIndex];
      const group = new THREE.Group();

      if (nodeDef.name) group.name = nodeDef.name;
      if (nodeDef.translation) group.position.fromArray(nodeDef.translation);
      if (nodeDef.rotation) group.quaternion.fromArray(nodeDef.rotation);
      if (nodeDef.scale) group.scale.fromArray(nodeDef.scale);
      if (nodeDef.matrix) {
        const matrix = new THREE.Matrix4().fromArray(nodeDef.matrix);
        matrix.decompose(group.position, group.quaternion, group.scale);
      }

      const pending = [];

      if (nodeDef.mesh !== undefined) {
        pending.push(scope.loadDependency('mesh', nodeDef.mesh).then(function (mesh) {
          group.add(mesh);
        }));
      }

      if (nodeDef.children) {
        for (let i = 0; i < nodeDef.children.length; i++) {
          pending.push(scope.loadDependency('node', nodeDef.children[i]).then(function (child) {
            group.add(child);
          }));
        }
      }

      return Promise.all(pending).then(function () {
        return group;
      });
    }

    loadScene(sceneIndex) {
      const scope = this;
      const sceneDef = this.json.scenes[sceneIndex];
      const scene = new THREE.Group();

      if (sceneDef.name) scene.name = sceneDef.name;

      const nodeIndices = sceneDef.nodes || [];
      const pending = [];

      for (let i = 0; i < nodeIndices.length; i++) {
        pending.push(scope.loadDependency('node', nodeIndices[i]).then(function (node) {
          scene.add(node);
        }));
      }

      return Promise.all(pending).then(function () {
        return scene;
      });
    }
  }

  THREE.GLTFLoader = GLTFLoader;
})();
