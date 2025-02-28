Shader "Environment/TessellationGeometryGrass"
{
    Properties
    {   
        [Header(Color)]
        _TopCol ("Top Color", Color) = (0,1,0,1)
        _BotCol ("Bottom Color", Color) = (0,0.5,0,1)
        [Space(10)]

        [Header(Shadow)]
        [Toggle(_MAIN_LIGHT_SHADOWS)] _MAIN_LIGHT_SHADOWS("Receive Shadow", Float) = 1
        _ShadowIntensity ("Shadow Intensity", Range(0, 1)) = 0.25
        [Header(Fake Shadow)]
        _FakeShadowIntensity ("Fake Shadow Intensity", Range(0, 1)) = 0.25
        _FakeShadowRange ("Fake Shadow Range", Range(0.1, 1)) = 0.5


        [Header(Shape Control)]
        _BendAmount ("Bend Amount", Range(0, 1)) = 0
        _BladeWidth ("Blade Width", Float) = 0.5
        _BladeHeight ("Blade Height", Float) = 1  
        _BladeWidthRand ("Blade Width Randomness", Range(0, 1)) = 0.1
        _BladeHeightRand ("Blade Height Randomness", Range(0, 1)) = 0
        [IntRange] _BladeBendCurve ("Blade Bend Curve", Range(1, 4)) = 2
        _BladeBendDistance ("Blade Bend Distance", Range(0, 3)) = 1.0
        _TessellationnEdgeLength ("Grass Inv_Density (Tessellation Edge Length)", Range(0, 0.1)) = 0.05
        [IntRange] _MaxEdgeFactor ("Max density (Max Edge Factor)", Range(1, 10)) = 4
        [Space(30)]

        [Header(Interactor)]
        _InteractorRadius ("Interactor Radius", Float) = 0.5
        _InteractorStrength ("Interactor Strength", Float) = 5
        [Space(30)]

        [Header(Wind)]
        _WindNoiseMap ("Wind Noise Map", 2D) = "white" {}
        _WindNoiseFrequency ("Wind Noise Frequency", Vector) = (0.5, 0.5, 0, 0)
        _WindStrength ("Wind Strength", Float) = 1
        [Space(30)]


        _Test ("Test Factor", Vector) = (0,0,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry" }
        Cull Off
        ZWrite On

        HLSLINCLUDE
            #pragma target 4.6

            #define BLADE_SEG_NUM 3

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/Common/Shader/KrusNoise.hlsl"

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            CBUFFER_START(UnityPerMaterial)
            half4 _TopCol;
            half4 _BotCol;

            half _BendAmount;
            half _BladeWidth;
            half _BladeHeight;
            half _BladeWidthRand;
            half _BladeHeightRand;
            int _BladeBendCurve;
            float _BladeBendDistance;
            float _TessellationnEdgeLength;
            half _MaxEdgeFactor;
            
            sampler2D _WindNoiseMap;
            float4 _WindNoiseMap_ST;
            float2 _WindNoiseFrequency;
            float _WindStrength;

            half _ShadowIntensity;
            half _FakeShadowIntensity;
            half _FakeShadowRange;
            
            uniform float3 _InteractorPos0;
            half _InteractorRadius;
            float _InteractorStrength;

            float4 _Test;
            CBUFFER_END

            // TEXTURE2D(_WindNoiseMap);   SAMPLER(sampler_WindNoiseMap);

            struct appdata
            {
                float4 pos : POSITION;
                half3 normal : NORMAL;
                half4 tangent : TANGENT;
                half2 uv : TEXCOORD0;
            };

            struct vertdata
            {
                float4 pos : SV_POSITION;
                half3 normal : NORMAL;
                half4 tangent : TANGENT;
                half2 uv : TEXCOORD0;
            };

            struct geomdata
            {
                float4 pos : SV_POSITION;
                // half3 normal : NORMAL;
                // half4 tangent : TANGENT;
                half2 uv : TEXCOORD0;
                float3 posWS : TEXCOORD1;
            };

            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };


            // TO DEFINE FACTOR BASED ON DISTANCE TO CAM //
            float TessellationEdgeFactor(float3 p0_WS, float3 p1_WS)
            {
                float edgeLength = distance(p0_WS, p1_WS);

                float3 edgeCenter = (p0_WS + p1_WS) * 0.5;
                float dstToCam = distance(edgeCenter, _WorldSpaceCameraPos.xyz);
                // _MaxEdgeFactor is to prevent the tessellation factor from being too high
                float factor = min(edgeLength / (_TessellationnEdgeLength * dstToCam), _MaxEdgeFactor);
                
                return factor;
            }
            

            // CONSTANT FUNCTION
            TessellationFactors ConstantFunction(InputPatch<appdata, 3> patch)
            {   
                float3 p0_WS = TransformObjectToWorld(patch[0].pos.xyz).xyz;
                float3 p1_WS = TransformObjectToWorld(patch[1].pos.xyz).xyz;
                float3 p2_WS = TransformObjectToWorld(patch[2].pos.xyz).xyz;
                

                TessellationFactors f;
                f.edge[0] = TessellationEdgeFactor(p0_WS, p1_WS);
                f.edge[1] = TessellationEdgeFactor(p1_WS, p2_WS);
                f.edge[2] = TessellationEdgeFactor(p2_WS, p0_WS);
                f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) * 0.333;
                return f;
            }

            // FUNCTION START ////////////////////////////////////////////////////////

            // assign properties to vertices created in geom shader
            geomdata GenerateGrassVertices(float3 newPosOS, float3 offset, float3x3 matrix_transformation, half2 uv)
            {
                geomdata o;
                o.pos = TransformObjectToHClip(newPosOS + mul(matrix_transformation, offset));
                o.uv = uv;
                o.posWS = TransformObjectToWorld(newPosOS + mul(matrix_transformation, offset)).xyz;
                return o;
            }

            // Construct a rotation matrix that rotates around the provided axis
            float3x3 angleAxis3x3(float angle, float3 axis)
			{
				float c, s;
				sincos(angle, s, c);

				float t = 1 - c;
				float x = axis.x;
				float y = axis.y;
				float z = axis.z;

				return float3x3
				(
					t * x * x + c, t * x * y - s * z, t * x * z + s * y,
					t * x * y + s * z, t * y * y + c, t * y * z - s * x,
					t * x * z - s * y, t * y * z + s * x, t * z * z + c
				);
			}

            // FUNCTION END ////////////////////////////////////////////////////////

            // VERT PROGRAM FOR TESSELLATION // 
            vertdata tessvert (appdata v)
            {
                vertdata o;
                o.pos = v.pos;
                o.normal = v.normal;
                o.tangent = v.tangent;
                o.uv = v.uv;
                return o;
            }

            // VERT SHADER //
            vertdata vert (appdata v)
            {
                appdata o;
                o.pos = v.pos;
                o.normal = v.normal;
                o.tangent = v.tangent;
                o.uv = v.uv;
                return o;
            }

            // HULL SHADER //
            [domain("tri")]
            [partitioning("integer")]
            [outputtopology("triangle_cw")] 
            [outputcontrolpoints(3)]
            [patchconstantfunc("ConstantFunction")]
            appdata hull(InputPatch<appdata, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

            // TESSELLATOR //

            // DOMAIN SHADER //
            [domain("tri")]
            vertdata domain(TessellationFactors factors, OutputPatch<appdata, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                appdata data;

                #define DOMAIN_INTERPOLATE(fieldName) data.fieldName = \
                    patch[0].fieldName * barycentricCoordinates.x + \
                    patch[1].fieldName * barycentricCoordinates.y + \
                    patch[2].fieldName * barycentricCoordinates.z;
                
                // interpolation
                DOMAIN_INTERPOLATE(pos)
                DOMAIN_INTERPOLATE(normal)
                DOMAIN_INTERPOLATE(tangent)
                DOMAIN_INTERPOLATE(uv)

                return tessvert(data);
            }

            // GEOM SHADER //
            [maxvertexcount(BLADE_SEG_NUM * 2 + 1)]
            void geom (triangle vertdata IN[3] : SV_POSITION, inout TriangleStream<geomdata> triStream)
            {
                // prepare variables
                float3 posOS = IN[0].pos.xyz ;
                float3 posWS = TransformObjectToWorld(posOS).xyz;
                half3 normal = IN[0].normal;
                half3 tangent = IN[0].tangent.xyz;
                half3 bitangent = cross(normal, tangent) * IN[0].tangent.w;


                // wind
                float2 windUV = posOS.xz * _WindNoiseMap_ST.xy + _WindNoiseMap_ST.zw + _WindNoiseFrequency * _Time.y;
                half2 windSample = (tex2Dlod(_WindNoiseMap, float4(windUV,0,0)).xy * 2 - 1) * _WindStrength;
                // rotation axis
                half3 windAxis = normalize(float3(windSample.x, windSample.y, 0));
                float3x3 matrix_windRotation = angleAxis3x3(PI * windSample.y, windAxis) ;

                // TBN matrix - TS to OS
                float3x3 matrix_TS2OS = transpose(float3x3(tangent, bitangent, normal));
                float3x3 matrix_randFaceRotation = angleAxis3x3(rand(posOS) * PI * 2, float3(0, 0, 1));
                float3x3 matrix_randBendRotation = angleAxis3x3(rand(posOS.zyx) * _BendAmount * PI * 0.5, float3(1, 0, 0));

                // final rotation matrix for base or top
                float3x3 matrix_transformation_tip = mul(mul(mul(matrix_TS2OS, matrix_windRotation), matrix_randFaceRotation), matrix_randBendRotation);
                float3x3 matrix_transformation_base = mul(matrix_TS2OS, matrix_randFaceRotation);

                // grass height & width
                half width = (rand(posOS.xyz) * 2 - 1) * _BladeWidthRand + _BladeWidth;
                half height = (rand(posOS.zyx) * 2 - 1) * _BladeHeightRand + _BladeHeight;
                half forward = rand(posOS.yxz) * _BladeBendDistance;

                // Interactivity 
                float dst = distance(_InteractorPos0, posWS);
                float3 radius = 1 - saturate (dst / _InteractorRadius);
                float3 sphereDisp = posWS - _InteractorPos0;
                sphereDisp *= radius;
                sphereDisp = clamp(sphereDisp * _InteractorStrength, -0.8, 0.8);

                // GENERATE VERTICES //
                // segment part
                for (int i = 0; i < BLADE_SEG_NUM; i++)
                {
                    float t = i / (float)BLADE_SEG_NUM;
                    // added vertices' pos info
                    float3 offset = float3(width * (1 - t), pow(t, _BladeBendCurve) * forward, height * t);
                    float3x3 matrix_transformation = (i == 0) ? matrix_transformation_base : matrix_transformation_tip;

                    // interactor force field
                    float3 newPosOS = (i == 0) ? posOS : posOS + sphereDisp * t;
                
                    triStream.Append(GenerateGrassVertices(newPosOS, float3(offset.x, offset.y, offset.z), matrix_transformation, float2(0, t)));
                    triStream.Append(GenerateGrassVertices(newPosOS, float3(-offset.x, offset.y, offset.z), matrix_transformation, float2(1, t)));
                    
                }
                
                // tip part
                triStream.Append(GenerateGrassVertices(posOS + sphereDisp * 1.3, float3(0, forward, height), matrix_transformation_tip, float2(0.5, 1)));
                

                triStream.RestartStrip();
            }

        ENDHLSL

        Pass
        {
            Name "GrassLighting"

            Tags 
            {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            #pragma require geometry
            #pragma require tessellation tessHW

            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain 
            #pragma geometry geom
            #pragma fragment frag
            
            // FRAG SHADER //
            half4 frag (geomdata i) : SV_Target
            {
                // grass color
                half3 col = 1;

                half fakeShadow = lerp( saturate(floor(i.uv.x / _FakeShadowRange) + (1 - _FakeShadowIntensity)), 1.0, i.uv.y);
                half3 lerpCol = lerp(_BotCol.xyz, _TopCol.xyz, i.uv.y);
                col = lerpCol * fakeShadow;

                // receive shadow
                #ifdef _MAIN_LIGHT_SHADOWS
                    VertexPositionInputs vertexInput = (VertexPositionInputs)0;
                    vertexInput.positionWS = i.posWS;
                    
                    half4 shadowCoord = GetShadowCoord(vertexInput);
                    half shadowAttenuation = saturate(MainLightRealtimeShadow(shadowCoord) + _ShadowIntensity);
                    half3 shadow = lerp(0.0f, 1.0f, shadowAttenuation);

                    // overlay shadow on grass color
                    col *= shadow;
                #endif

                return half4(col, 1);
            }
            ENDHLSL
        }

        Pass 
        {
            Name "GrassShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            HLSLPROGRAM

            // #pragma require geometry
            // #pragma require tessellation tessHW

            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain 
            #pragma geometry geom
            #pragma fragment frag

            #pragma target 4.6
            #pragma multi_compile_shadowcaster

            half4 frag(geomdata i) : SV_Target
            {
                return 0;
            }

            ENDHLSL
        }
    }
}
