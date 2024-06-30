using System.Text;

namespace QueueWorker;

public interface IBodyDecoder
{
    string Decode(BinaryData body);   
}

public sealed class Base64BodyDecoder : IBodyDecoder
{
    public string Decode(BinaryData body) => Encoding.UTF8.GetString(Convert.FromBase64String(body.ToString()));
}

public sealed class IdentityBodyDecoder : IBodyDecoder
{
    public string Decode(BinaryData body) => body.ToString();
}