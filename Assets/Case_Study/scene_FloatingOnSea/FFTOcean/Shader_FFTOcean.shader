Shader "KrusShader/FFTOcean"
{
    Properties
    {
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
        [Toggle(UV_POS_OS)] _UV_POS_OS ("Enable UV POS OS", Float) = 0
        _Test ("Test", Vector) = (1,1,1,1)

        [Space(10)]
        _ReflecCubemap ("Reflection Cubemap", Cube) = "" {}
        _OceanTile ("Ocean Tile", 2D) = "" {}
        _OceanLitTex ("Ocean Lit Texture", 2D) = "" {}
        _LOD ("LOD", Range(0, 12)) = 0
        _HexSize ("Hex Size", Float) = 0.1
        _EdgeContrast ("Edge Contrast", Float) = 1

        [Header(Layer 0)]
        [HDR]_Col0 ("Color 0", Color) = (1,1,1,1)
        _LOD0 ("LOD 0", Range(0, 12)) = 0
        _Power0 ("Contrast 0", Float) = 1
        _FlowScale0 ("Flow Scale 0", Range(0, 1)) = 0.1
        _ScaleTranslation0 ("Scale Translation 0", Vector) = (1,1,0,0)

        [Header(Layer 1)]
        [HDR]_Col1 ("Color 1", Color) = (1,1,1,1)
        _LOD1 ("LOD 1", Range(0, 12)) = 0
        _Power1 ("Contrast 1", Float) = 1
        _FlowScale1 ("Flow Scale 1", Range(0, 1)) = 0.1
        _ScaleTranslation1 ("Scale Translation 1", Vector) = (1,1,0,0)

        [Header(Layer 2)]
        [HDR]_Col2 ("Color 2", Color) = (1,1,1,1)
        _LOD2 ("LOD 2", Range(0, 12)) = 0
        _Power2 ("Contrast 2", Float) = 1
        _FlowScale2 ("Flow Scale 2", Range(0, 1)) = 0.1
        _ScaleTranslation2 ("Scale Translation 2", Vector) = (1,1,0,0)

        [Header(Layer 3)]
        [HDR]_Col3 ("Color 3", Color) = (1,1,1,1)
        _LOD3 ("LOD 3", Range(0, 12)) = 0
        _Power3 ("Contrast 3", Float) = 1
        _FlowScale3 ("Flow Scale 3", Range(0, 1)) = 0.1
        _ScaleTranslation3 ("Scale Translation 3", Vector) = (1,1,0,0)

        [Header(Color)]
        [HDR]_SpecCol ("Specular Color", Color) = (1,1,1,1)
        _ShallowCol ("Shallow Color", Color) = (0,0,1,1)
        _DeepCol ("Deep Color", Color) = (0,0,0.5,1)
        _AstronautTexScaleTranslation ("Astronaut Tex Scale Translation", Vector) = (1,0,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Geometry" "RenderPipeline"="UniversalRenderPipeline" "Queue"="Geometry"}


        Pass
        {
            Tags {"LightMode"="UniversalForward"}
            ZWrite On

            HLSLPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag

            #pragma require tessellation tessHW

            #pragma multi_compile _ UV_POS_OS


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"
            #include "Assets/Common/Shader/TextureTilingRandomization.hlsl"

            struct appdata
            {
                float4 posOS : POSITION;
                half3 normalOS : NORMAL;
                half4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct tessdata
            {
                float4 posOS : POSITION;
                half3 normalWS : NORMAL;
                half4 tangentWS : TANGENT;
                float2 uv : TEXCOORD0;
                half3 barycentricCoordinates : TEXCOORD1;
                half3 posWS : TEXCOORD2;
            };

            struct vertdata
            {
                float4 pos : SV_POSITION;
                half3 normalWS : NORMAL;
                half4 tangentWS : TANGENT;
                half2 uv : TEXCOORD0;
                half3 barycentricCoordinates : TEXCOORD1;
                float3 posWS : TEXCOORD2;
                float3 posOS : TEXCOORD3;
            };

            // FFT PRAMS
            float _TileGlobalScale;
            float _GlobalScale;
            float _TessellationFactor;

            float4 _MainTex_ST;
            float4 _OceanTile_ST;
            float4 _Test;

            float _Tile0, _Tile1, _Tile2, _Tile3;
			int _DebugTile0, _DebugTile1, _DebugTile2, _DebugTile3;
			int _DebugLayer0, _DebugLayer1, _DebugLayer2, _DebugLayer3;
			int _ContributeDisplacement0, _ContributeDisplacement1, _ContributeDisplacement2, _ContributeDisplacement3;
            
            // COLOR
            half3 _ShallowCol;
            half3 _DeepCol;
            half3 _Col0;
            half3 _Col1;
            half3 _Col2;
            half3 _Col3;

            half3 _SpecCol;
            
            float _Power0;
            float _Power1;
            float _Power2;
            float _Power3;
            
            float _LOD0;
            float _LOD1;
            float _LOD2;
            float _LOD3;

            float _FlowScale0;
            float _FlowScale1;
            float _FlowScale2;
            float _FlowScale3;

            float4 _ScaleTranslation0;
            float4 _ScaleTranslation1;
            float4 _ScaleTranslation2;
            float4 _ScaleTranslation3;

            float _LOD;
            float _HexSize;
            float _EdgeContrast;

            float4 _AstronautTexScaleTranslation;

            TEXTURE2D_ARRAY(_DisplacementTextures);     SAMPLER(sampler_DisplacementTextures);
            TEXTURE2D_ARRAY(_SlopeTextures);            SAMPLER(sampler_SlopeTextures);
            TEXTURE2D(_MainTex);                        SAMPLER(sampler_MainTex);
            TEXTURECUBE(_ReflecCubemap);                SAMPLER(sampler_ReflecCubemap);
            TEXTURE2D(_OceanTile);                      SAMPLER(sampler_OceanTile);
            TEXTURE2D(_OceanLitTex);                    SAMPLER(sampler_OceanLitTex);
            sampler2D _AstronautDepthTex;

            //////////////////////////////////////////////////////////////////////////////////////////////
            //////////////////////////              VERTEX SHADER                /////////////////////////
            //////////////////////////////////////////////////////////////////////////////////////////////

            tessdata vert(appdata v)
            {
                tessdata o;

                o.posOS = v.posOS;
                o.normalWS = TransformObjectToWorldDir(v.normalOS);
                o.tangentWS.xyz = TransformObjectToWorldDir(v.tangentOS);
                o.posWS = TransformObjectToWorld(v.posOS).xyz;
                o.uv = TRANSFORM_TEX(v.uv, _OceanTile);
                return o;
            }

            //////////////////////////////////////////////////////////////////////////////////////////////
            //////////////////////////                HULL SHADER                /////////////////////////
            //////////////////////////////////////////////////////////////////////////////////////////////

            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            // Constant function
            // invoked once per patch
            // to specify how many parts the patch should be divided into
            TessellationFactors ConstantFunction(InputPatch<appdata, 3> patch)
            {
                TessellationFactors f;
                f.edge[0] = _TessellationFactor;
                f.edge[1] = _TessellationFactor;
                f.edge[2] = _TessellationFactor;
                f.inside = _TessellationFactor;
                return f;
            }

            // evoked once per vertex in a patch
            // to break high-level mesh into a series of smaller patches and pass them to tessellation shader
            [domain("tri")]     // work with triangle
            [outputcontrolpoints(3)]    // output 3 control points per patch
            [outputtopology("triangle_cw")]     // output triangle with clockwise winding
            [partitioning("fractional_even")]   // integer partitioning mode
            [patchconstantfunc("ConstantFunction")]    // use constant function to calculate patch constant data
            appdata hull(InputPatch<appdata, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

            //////////////////////////////////////////////////////////////////////////////////////////////
            //////////////////////////      TESSELLATION SHADER  (On Hardware)   /////////////////////////
            //////////////////////////////////////////////////////////////////////////////////////////////

            //////////////////////////////////////////////////////////////////////////////////////////////
            //////////////////////////               DOMAIN SHADER               /////////////////////////
            //////////////////////////////////////////////////////////////////////////////////////////////

            vertdata tessvert(tessdata v)
            {
                vertdata o;
                o.pos = TransformObjectToHClip(v.posOS);
                o.normalWS = normalize(v.normalWS);
                o.tangentWS = v.tangentWS;
                o.uv = v.uv;
                o.barycentricCoordinates = v.barycentricCoordinates;
                o.posWS = v.posWS;
                o.posOS = v.posOS;
                return o;
            }

            // invoked once per vertex in a patch
            // use baycentric coordinates to generate vertices
            [domain("tri")]
            vertdata domain(TessellationFactors factors, OutputPatch<tessdata, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                tessdata data;

                #define DOMAIN_INTERPOLATE(fieldName) data.fieldName = \
                    patch[0].fieldName * barycentricCoordinates.x + \
                    patch[1].fieldName * barycentricCoordinates.y + \
                    patch[2].fieldName * barycentricCoordinates.z;
                
                // interpolation
                DOMAIN_INTERPOLATE(posOS)
                DOMAIN_INTERPOLATE(posWS)
                DOMAIN_INTERPOLATE(normalWS)
                DOMAIN_INTERPOLATE(tangentWS)
                DOMAIN_INTERPOLATE(uv)

                data.barycentricCoordinates = barycentricCoordinates;

                #ifdef UV_POS_OS
                    float2 uv = float2(data.posOS.x, data.posOS.z) / _TileGlobalScale ;
                #else
                    float2 uv = data.uv;
                #endif

                half3 displacement1 = SAMPLE_TEXTURE2D_ARRAY_LOD(_DisplacementTextures, sampler_DisplacementTextures, uv * _Tile0, 0, 0) * _DebugLayer0 * _ContributeDisplacement0;
                half3 displacement2 = SAMPLE_TEXTURE2D_ARRAY_LOD(_DisplacementTextures, sampler_DisplacementTextures, (uv - 0.5f) * _Tile1, 1, 0) * _DebugLayer1 * _ContributeDisplacement1;
                half3 displacement3 = SAMPLE_TEXTURE2D_ARRAY_LOD(_DisplacementTextures, sampler_DisplacementTextures, (uv - 1.125f) * _Tile2, 2, 0) * _DebugLayer2 * _ContributeDisplacement2;
                half3 displacement4 = SAMPLE_TEXTURE2D_ARRAY_LOD(_DisplacementTextures, sampler_DisplacementTextures, (uv - 1.25f) * _Tile3, 3, 0) * _DebugLayer3 * _ContributeDisplacement3;
				half3 displacement = displacement1 + displacement2 + displacement3;

                // displace in tangent space
                float3 tangentOS = normalize(TransformWorldToObjectDir(data.tangentWS.xyz));
                float3 normalOS = normalize(TransformWorldToObjectDir(data.normalWS));
                float3 bitangentOS = normalize(cross(tangentOS, normalOS));
                float3x3 matrix_TangentToObject = float3x3(
                    tangentOS,
                    normalOS,
                    bitangentOS
                );

                data.posOS.xyz += mul(matrix_TangentToObject ,displacement * _GlobalScale * 0.001f);

                return tessvert(data);
            }

            //////////////////////////////////////////////////////////////////////////////////////////////
            //////////////////////////              FRAGMENT SHADER              /////////////////////////
            //////////////////////////////////////////////////////////////////////////////////////////////

            half4 frag (vertdata i) : SV_Target
            {
                Light mainLight;
                mainLight = GetMainLight();
                
                // uv by posOS
                #ifdef UV_POS_OS
                    float2 uv = float2(i.posOS.x, i.posOS.z) / _TileGlobalScale;
                #else
                    float2 uv = i.uv;
                #endif

                // half3 displacement1 = SAMPLE_TEXTURE2D_ARRAY(_DisplacementTextures, sampler_DisplacementTextures, uv * _Tile0, 0) * _DebugLayer0 * _ContributeDisplacement0;
                // half3 displacement2 = SAMPLE_TEXTURE2D_ARRAY(_DisplacementTextures, sampler_DisplacementTextures, (uv - 0.5f) * _Tile1, 1) * _DebugLayer1 * _ContributeDisplacement1;
                // half3 displacement3 = SAMPLE_TEXTURE2D_ARRAY(_DisplacementTextures, sampler_DisplacementTextures, (uv - 1.125f) * _Tile2, 2) * _DebugLayer2 * _ContributeDisplacement2;
                // // half3 displacement4 = SAMPLE_TEXTURE2D_ARRAY(_DisplacementTextures, sampler_DisplacementTextures, (uv - 1.25f) * _Tile3, 3) * _DebugLayer3 * _ContributeDisplacement3;
				// half3 displacement = displacement1 + displacement2 + displacement3;

                float2 slopes1 = SAMPLE_TEXTURE2D_ARRAY(_SlopeTextures, sampler_SlopeTextures, uv * _Tile0, 0) * _DebugLayer0;
				float2 slopes2 = SAMPLE_TEXTURE2D_ARRAY(_SlopeTextures, sampler_SlopeTextures, (uv - 0.5) * _Tile1, 1) * _DebugLayer1;
				float2 slopes3 = SAMPLE_TEXTURE2D_ARRAY(_SlopeTextures, sampler_SlopeTextures, (uv - 1.125) * _Tile2, 2) * _DebugLayer2;
				// float2 slopes4 = SAMPLE_TEXTURE2D_ARRAYY(_SlopeTextures, sampler_SlopeTextures, (uv - 1.25) * _Tile3, 3) * _DebugLayer3;
				float2 slopes = slopes1 + slopes2 + slopes3;
                
                // Vector 
				float3 n_WS = normalize(float3(-slopes.x, 1.0f, -slopes.y));
                float3 l_WS = mainLight.direction;
                float3 v_WS = normalize(_WorldSpaceCameraPos - i.posWS);
                float3 h_WS = normalize(l_WS + v_WS);
                float HoV_WS = max(dot(h_WS, n_WS), 0.00001);
                float NoV_WS = max(dot(n_WS, v_WS), 0.00001);
                float3 reflect_WS = reflect(-v_WS, n_WS);
                float3 refrac_WS = refract(-v_WS, n_WS, _Test.y);
                float3 fresnel = 0.04 + (1 - 0.04) * pow(1.0f - NoV_WS, 10);
                
                // Shading 
                float2 uv0 = (uv * _ScaleTranslation0.xy + _ScaleTranslation0.zw) + slopes.xy * _FlowScale0;
                float2 uv1 = (uv * _ScaleTranslation1.xy + _ScaleTranslation1.zw) + slopes.xy * _FlowScale1;
                float2 uv2 = (uv * _ScaleTranslation2.xy + _ScaleTranslation2.zw) + slopes.xy * _FlowScale2;
                half3 oceanTileTex0 = SampleTextureRandomizedHexGrid(TEXTURE2D_ARGS(_OceanTile, sampler_OceanTile), uv0, _LOD0, _HexSize, _EdgeContrast).rgb;
                half3 oceanTileTex1 = SampleTextureRandomizedHexGrid(TEXTURE2D_ARGS(_OceanTile, sampler_OceanTile), uv1, _LOD1, _HexSize, _EdgeContrast).rgb;
                half3 oceanTileTex2 = SampleTextureRandomizedHexGrid(TEXTURE2D_ARGS(_OceanTile, sampler_OceanTile), uv2, _LOD2, _HexSize, _EdgeContrast).rgb;
                half3 col0 = pow(oceanTileTex0, _Power0) * _Col0; 
                half3 col1 = pow(oceanTileTex1, _Power1) * _Col1;
                half3 col2 = pow(oceanTileTex2, _Power2) * _Col2;
                half3 baseCol = col0 + col1 + col2;
                
                half3 specCol = _SpecCol * fresnel * baseCol;
                half4 val = SAMPLE_TEXTURECUBE(unity_SpecCube0, samplerunity_SpecCube0, reflect_WS);
                half3 reflCol = DecodeHDREnvironment(val, unity_SpecCube0_HDR) * fresnel * _SpecCol;

                // // Foam
                float2 uv_screen = i.pos.xy / _ScaledScreenParams.xy;
                float depth = SampleSceneDepth(uv_screen);
                float3 posWS_depth = ComputeWorldSpacePosition(uv_screen, depth, UNITY_MATRIX_I_VP);
                // float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv_screen).r;
                // float4 posHCS_depth = float4(uv_screen * 2 - 1, depth, 1.0);
                // float4 posWS_depth = mul(UNITY_MATRIX_I_VP, posHCS_depth);
                // posWS_depth.xyz /= posWS_depth.w;
                float dist = distance(posWS_depth, i.posWS);
                dist = 1 - step(_Test.x, dist);

                // float2 uv_astronaut = i.uv / _OceanTile_ST.xy;
                // uv_astronaut = (uv_astronaut - 0.5) * _AstronautTexScaleTranslation.xy + 0.5;
                // uv_astronaut += _AstronautTexScaleTranslation.zw;
                // half astronautDepth = tex2D(_AstronautDepthTex, uv_astronaut).r;

                half3 col;
                col = baseCol + reflCol;
                return half4(col, 1);
            }
            ENDHLSL
        }
    }
}
