using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RipplesTextureTest : MonoBehaviour
{
    [SerializeField]
    Texture _rt_input;

    [SerializeField]
    Texture _rt_after_input;

    [SerializeField]
    RenderTexture _rt_prev;

    [SerializeField]
    RenderTexture _rt_prevprev;

    [SerializeField]
    RenderTexture _rt_front;

    [SerializeField]
    Material _mat_ripples;

    RenderTexture[] rt_list = new RenderTexture[3];

    int _front_id;

    float _continuetion_sec;

    // Start is called before the first frame update
    void Start()
    {
        _front_id = 0;
        int prev_id = (_front_id + 2)%3;
        int prevprev_id = (_front_id + 1) % 3;

        rt_list[_front_id]  = _rt_front;
        rt_list[prev_id]    = _rt_prev;
        rt_list[prevprev_id]= _rt_prevprev;

        Graphics.SetRenderTarget(null);

        Graphics.Blit(_rt_input,rt_list[prev_id]);
        Graphics.Blit(_rt_after_input,rt_list[prevprev_id]);

        _mat_ripples.SetTexture(Shader.PropertyToID("_PrevTex"),rt_list[prev_id]);
        _mat_ripples.SetTexture(Shader.PropertyToID("_PrevPrevTex"),rt_list[prevprev_id]);
        _mat_ripples.SetTexture(Shader.PropertyToID("_InputTex"),_rt_after_input);

        
        Graphics.SetRenderTarget(rt_list[_front_id]);
        GL.Clear(false /* clearDepth */,true /* clearColor */,new Color(0.5f,0.5f,0.5f,0.5f));
        Graphics.Blit(rt_list[prev_id],rt_list[_front_id],_mat_ripples);

        _front_id = prevprev_id;
    }

    private void Update()
    {
        int prev_id = (_front_id + 2) % 3;
        int prevprev_id = (_front_id + 1) % 3;

        if(_continuetion_sec <= 0.40f)
        {
            _mat_ripples.SetTexture(Shader.PropertyToID("_InputTex"),_rt_after_input);
            _continuetion_sec += Time.deltaTime;
        }
        else
        {
            // Graphics.Blit(_rt_input,rt_list[prev_id]);
            _mat_ripples.SetTexture(Shader.PropertyToID("_InputTex"),_rt_input);
            _continuetion_sec = 0.0f;
        }

        _mat_ripples.SetTexture(Shader.PropertyToID("_PrevTex"),rt_list[prev_id]);
        _mat_ripples.SetTexture(Shader.PropertyToID("_PrevPrevTex"),rt_list[prevprev_id]);
        // _mat_ripples.SetTexture(Shader.PropertyToID("_InputTex"),_rt_after_input);

        // Graphics.SetRenderTarget(null);
        Graphics.SetRenderTarget(rt_list[_front_id]);
        GL.Clear(false /* clearDepth */,true /* clearColor */,new Color(0.5f,0.5f,0.5f,0.5f));
        Graphics.Blit(rt_list[prev_id],rt_list[_front_id],_mat_ripples);

        _front_id = prevprev_id;

        
    }
}
